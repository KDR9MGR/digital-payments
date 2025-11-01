#!/bin/bash

# Setup Cloud SQL PostgreSQL database for Digital Payments App

set -e

PROJECT_ID="digital-payments-52cac"
REGION="us-central1"
INSTANCE_NAME="digital-payments-db"
DATABASE_NAME="digital_payments"
DB_USER="app_user"

echo "🗄️  Setting up Cloud SQL PostgreSQL database"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Instance: $INSTANCE_NAME"
echo ""

# Check if instance already exists
if gcloud sql instances describe $INSTANCE_NAME --project=$PROJECT_ID >/dev/null 2>&1; then
    echo "⚠️  Cloud SQL instance $INSTANCE_NAME already exists"
    echo "Skipping instance creation..."
else
    echo "Creating Cloud SQL PostgreSQL instance..."
    gcloud sql instances create $INSTANCE_NAME \
        --database-version=POSTGRES_15 \
        --tier=db-f1-micro \
        --region=$REGION \
        --storage-type=SSD \
        --storage-size=10GB \
        --storage-auto-increase \
        --backup-start-time=03:00 \
        --maintenance-window-day=SUN \
        --maintenance-window-hour=04 \
        --project=$PROJECT_ID
    
    echo "✅ Cloud SQL instance created successfully"
fi

# Generate a random password for the database user
DB_PASSWORD=$(openssl rand -base64 32)

echo ""
echo "Creating database and user..."

# Create the database
gcloud sql databases create $DATABASE_NAME \
    --instance=$INSTANCE_NAME \
    --project=$PROJECT_ID

# Create the database user
gcloud sql users create $DB_USER \
    --instance=$INSTANCE_NAME \
    --password=$DB_PASSWORD \
    --project=$PROJECT_ID

echo "✅ Database and user created successfully"

# Get the connection name
CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME --project=$PROJECT_ID --format="value(connectionName)")

# Create the database URL
DATABASE_URL="postgresql://$DB_USER:$DB_PASSWORD@/$DATABASE_NAME?host=/cloudsql/$CONNECTION_NAME"

echo ""
echo "📝 Adding database URL to Secret Manager..."

# Add the database URL to Secret Manager
echo "$DATABASE_URL" | gcloud secrets versions add database-url --data-file=- --project=$PROJECT_ID

echo "✅ Database URL added to Secret Manager"

echo ""
echo "🎉 Database setup completed successfully!"
echo ""
echo "Database Details:"
echo "  Instance: $INSTANCE_NAME"
echo "  Database: $DATABASE_NAME"
echo "  User: $DB_USER"
echo "  Connection Name: $CONNECTION_NAME"
echo ""
echo "The database URL has been securely stored in Secret Manager."
echo "Your Cloud Run service will automatically connect using this URL."