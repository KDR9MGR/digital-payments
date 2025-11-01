#!/bin/bash

# Interactive script to add secret values to Google Secret Manager

set -e

PROJECT_ID="digital-payments-52cac"

echo "🔐 Adding secret values to Google Secret Manager"
echo "Project: $PROJECT_ID"
echo ""

# Function to add secret value
add_secret_value() {
    local secret_name=$1
    local description=$2
    
    echo "📝 $description"
    echo -n "Enter value for $secret_name (input will be hidden): "
    read -s secret_value
    echo ""
    
    if [ -z "$secret_value" ]; then
        echo "⚠️  Empty value provided for $secret_name, skipping..."
        return
    fi
    
    echo "$secret_value" | gcloud secrets versions add $secret_name --data-file=- --project=$PROJECT_ID
    echo "✅ Added value for $secret_name"
    echo ""
}

# Add values for all secrets
echo "Please provide values for the following secrets:"
echo ""

add_secret_value "stripe-secret-key" "Stripe Secret Key (starts with sk_)"
add_secret_value "plaid-client-id" "Plaid Client ID"
add_secret_value "plaid-secret" "Plaid Secret Key"
add_secret_value "jwt-secret" "JWT Secret (use a strong random string)"

echo "🎉 All secret values have been added successfully!"
echo ""
echo "Note: Database URL will be set up when we configure Cloud SQL"