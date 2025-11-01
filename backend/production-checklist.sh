#!/bin/bash

# Production Deployment Checklist and Testing Script
# Digital Payments App - Google Cloud Platform

set -e

PROJECT_ID="digital-payments-52cac"
REGION="us-central1"
SERVICE_NAME="digital-payments-backend"

echo "🚀 Digital Payments App - Production Deployment Checklist"
echo "========================================================"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check status
check_status() {
    local service=$1
    local status=$2
    if [ "$status" = "✅" ]; then
        echo "✅ $service"
    else
        echo "❌ $service"
    fi
}

echo "📋 Pre-deployment Checklist:"
echo "----------------------------"

# Check gcloud authentication
if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    check_status "Google Cloud Authentication" "✅"
else
    check_status "Google Cloud Authentication" "❌"
    echo "   Run: gcloud auth login"
fi

# Check project setting
current_project=$(gcloud config get-value project 2>/dev/null)
if [ "$current_project" = "$PROJECT_ID" ]; then
    check_status "Project Configuration ($PROJECT_ID)" "✅"
else
    check_status "Project Configuration" "❌"
    echo "   Run: gcloud config set project $PROJECT_ID"
fi

# Check if secrets exist
echo ""
echo "🔐 Checking Secret Manager:"
echo "---------------------------"

secrets=("stripe-secret-key" "plaid-client-id" "plaid-secret" "database-url" "jwt-secret")
for secret in "${secrets[@]}"; do
    if gcloud secrets describe $secret --project=$PROJECT_ID >/dev/null 2>&1; then
        # Check if secret has a value
        if gcloud secrets versions list $secret --project=$PROJECT_ID --limit=1 --format="value(name)" | grep -q .; then
            check_status "Secret: $secret" "✅"
        else
            check_status "Secret: $secret (no value)" "❌"
        fi
    else
        check_status "Secret: $secret" "❌"
    fi
done

# Check Cloud SQL instance
echo ""
echo "🗄️  Checking Cloud SQL:"
echo "----------------------"

if gcloud sql instances describe digital-payments-db --project=$PROJECT_ID >/dev/null 2>&1; then
    instance_state=$(gcloud sql instances describe digital-payments-db --project=$PROJECT_ID --format="value(state)")
    if [ "$instance_state" = "RUNNABLE" ]; then
        check_status "Cloud SQL Instance (digital-payments-db)" "✅"
    else
        check_status "Cloud SQL Instance (state: $instance_state)" "❌"
    fi
else
    check_status "Cloud SQL Instance" "❌"
fi

# Check service account
echo ""
echo "👤 Checking Service Account:"
echo "----------------------------"

if gcloud iam service-accounts describe digital-payments-sa@$PROJECT_ID.iam.gserviceaccount.com --project=$PROJECT_ID >/dev/null 2>&1; then
    check_status "Service Account (digital-payments-sa)" "✅"
else
    check_status "Service Account" "❌"
fi

echo ""
echo "🚀 Deployment Commands:"
echo "----------------------"
echo "1. Add secret values (if not done):"
echo "   ./add-secret-values.sh"
echo ""
echo "2. Deploy to Cloud Run:"
echo "   ./deploy.sh $PROJECT_ID $REGION"
echo ""
echo "3. Test deployment:"
echo "   ./test-deployment.sh"
echo ""

# Check if service is already deployed
if gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID >/dev/null 2>&1; then
    SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --format="value(status.url)")
    echo "🌐 Current Service URL: $SERVICE_URL"
    echo ""
    echo "🧪 Quick Health Check:"
    echo "---------------------"
    
    if command_exists curl; then
        echo "Testing health endpoint..."
        if curl -s -f "$SERVICE_URL/health" >/dev/null; then
            check_status "Health Endpoint" "✅"
        else
            check_status "Health Endpoint" "❌"
        fi
    else
        echo "curl not available for testing"
    fi
fi

echo ""
echo "📚 Next Steps:"
echo "-------------"
echo "1. Ensure all checklist items are ✅"
echo "2. Run deployment script"
echo "3. Test all endpoints"
echo "4. Update Flutter app with production URL"
echo "5. Set up monitoring and alerts"
echo ""
echo "For detailed instructions, see: DEPLOYMENT_GUIDE.md"