#!/bin/bash

# Complete Database Setup for Digital Payments App
# This script finishes the database configuration and generates the database URL

set -e

PROJECT_ID="digital-payments-52cac"
DB_INSTANCE="digital-payments-db"
DB_NAME="digital_payments"
DB_USER="app_user"
DB_REGION="us-central1"

echo "🗄️ Completing database setup for Digital Payments"
echo "Project: $PROJECT_ID"
echo "Instance: $DB_INSTANCE"
echo ""

# Generate a secure random password
echo "🔐 Generating secure database password..."
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Set the password for the app_user
echo "Setting password for database user: $DB_USER"
gcloud sql users set-password "$DB_USER" \
    --instance="$DB_INSTANCE" \
    --password="$DB_PASSWORD" \
    --project="$PROJECT_ID"

echo "✅ Database user password set successfully"

# Create the database if it doesn't exist
echo "📊 Creating database: $DB_NAME"
gcloud sql databases create "$DB_NAME" \
    --instance="$DB_INSTANCE" \
    --project="$PROJECT_ID" 2>/dev/null || echo "Database already exists"

echo "✅ Database created/verified"

# Store the password in Secret Manager
echo "🔐 Storing database password in Secret Manager..."
echo "$DB_PASSWORD" | gcloud secrets versions add "db-password" --data-file=- --project="$PROJECT_ID" 2>/dev/null || {
    # Create the secret if it doesn't exist
    gcloud secrets create "db-password" --project="$PROJECT_ID"
    echo "$DB_PASSWORD" | gcloud secrets versions add "db-password" --data-file=- --project="$PROJECT_ID"
}

echo "✅ Database password stored in Secret Manager"

# Get the connection name
CONNECTION_NAME=$(gcloud sql instances describe "$DB_INSTANCE" --project="$PROJECT_ID" --format="value(connectionName)")

# Create database URL for Cloud Run (using Unix socket)
DATABASE_URL="postgresql://$DB_USER:$DB_PASSWORD@localhost/$DB_NAME?host=/cloudsql/$CONNECTION_NAME"

# Update database URL in Secret Manager
echo "🔗 Updating database URL in Secret Manager..."
echo "$DATABASE_URL" | gcloud secrets versions add "database-url" --data-file=- --project="$PROJECT_ID"

echo "✅ Database URL updated in Secret Manager"

echo ""
echo "🎉 Database setup completed successfully!"
echo ""
echo "📋 Database Configuration:"
echo "✅ Instance: $DB_INSTANCE (RUNNABLE)"
echo "✅ Database: $DB_NAME"
echo "✅ User: $DB_USER"
echo "✅ Password: Stored in Secret Manager"
echo "✅ Connection: $CONNECTION_NAME"
echo ""
echo "🚀 Ready for Cloud Run deployment!"