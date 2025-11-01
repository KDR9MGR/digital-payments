#!/bin/bash

# Setup secrets in Google Secret Manager for Digital Payments App

set -e

PROJECT_ID="digital-payments-52cac"

echo "🔐 Setting up secrets in Google Secret Manager for project: $PROJECT_ID"

# Function to create a secret
create_secret() {
    local secret_name=$1
    local description=$2
    
    echo "Creating secret: $secret_name"
    
    # Check if secret already exists
    if gcloud secrets describe $secret_name --project=$PROJECT_ID >/dev/null 2>&1; then
        echo "Secret $secret_name already exists, skipping creation..."
    else
        gcloud secrets create $secret_name \
            --replication-policy="automatic" \
            --project=$PROJECT_ID \
            --labels="app=digital-payments,env=production"
        echo "✅ Created secret: $secret_name"
    fi
}

# Create all required secrets
create_secret "stripe-secret-key" "Stripe secret key for payment processing"
create_secret "plaid-client-id" "Plaid client ID for bank account integration"
create_secret "plaid-secret" "Plaid secret key for bank account integration"
create_secret "database-url" "PostgreSQL database connection URL"
create_secret "jwt-secret" "JWT secret for authentication tokens"

echo ""
echo "🎉 All secrets created successfully!"
echo ""
echo "Next steps:"
echo "1. Add secret values using:"
echo "   gcloud secrets versions add stripe-secret-key --data-file=- <<< 'your-stripe-secret-key'"
echo "   gcloud secrets versions add plaid-client-id --data-file=- <<< 'your-plaid-client-id'"
echo "   gcloud secrets versions add plaid-secret --data-file=- <<< 'your-plaid-secret'"
echo "   gcloud secrets versions add database-url --data-file=- <<< 'your-database-url'"
echo "   gcloud secrets versions add jwt-secret --data-file=- <<< 'your-jwt-secret'"
echo ""
echo "2. Or use the interactive script: ./add-secret-values.sh"