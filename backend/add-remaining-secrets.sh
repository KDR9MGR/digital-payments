#!/bin/bash

# Add remaining secret values to Google Secret Manager (without Plaid)
# For Digital Payments App

set -e

PROJECT_ID="digital-payments-52cac"

echo "🔐 Adding remaining secret values to Google Secret Manager"
echo "Project: $PROJECT_ID"
echo ""

# Function to add secret value
add_secret_value() {
    local secret_name=$1
    local description=$2
    
    echo "📝 $description"
    read -s -p "Enter value for $secret_name (input will be hidden): " secret_value
    echo ""
    
    if [ -z "$secret_value" ]; then
        echo "❌ Empty value provided for $secret_name. Skipping..."
        return 1
    fi
    
    # Add the secret value
    echo "$secret_value" | gcloud secrets versions add "$secret_name" --data-file=- --project="$PROJECT_ID"
    echo "✅ Added value for $secret_name"
    echo ""
}

echo "Adding JWT Secret..."
add_secret_value "jwt-secret" "JWT Secret (for token signing - use a strong random string)"

echo "🗄️ Generating and adding database URL..."

# Get database connection details
DB_INSTANCE="digital-payments-db"
DB_NAME="digital_payments"
DB_USER="app_user"
DB_REGION="us-central1"

# Get the database password from the secret
DB_PASSWORD=$(gcloud secrets versions access latest --secret="db-password" --project="$PROJECT_ID" 2>/dev/null || echo "")

if [ -z "$DB_PASSWORD" ]; then
    echo "❌ Database password not found. Please run setup-database.sh first."
    exit 1
fi

# Get the connection name
CONNECTION_NAME=$(gcloud sql instances describe "$DB_INSTANCE" --project="$PROJECT_ID" --format="value(connectionName)")

# Create database URL for Cloud Run (using Unix socket)
DATABASE_URL="postgresql://$DB_USER:$DB_PASSWORD@localhost/$DB_NAME?host=/cloudsql/$CONNECTION_NAME"

# Add database URL to Secret Manager
echo "$DATABASE_URL" | gcloud secrets versions add "database-url" --data-file=- --project="$PROJECT_ID"
echo "✅ Added database URL to Secret Manager"

echo ""
echo "🎉 All required secrets have been configured!"
echo ""
echo "📋 Configured secrets:"
echo "✅ stripe-secret-key"
echo "✅ jwt-secret"
echo "✅ database-url"
echo "❌ plaid-client-id (skipped)"
echo "❌ plaid-secret (skipped)"
echo ""
echo "🚀 Ready to deploy to Cloud Run!"
echo "Run: ./deploy.sh"