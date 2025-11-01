#!/bin/bash

# Test Deployment Script for Digital Payments App
# Tests all endpoints and functionality after deployment

set -e

PROJECT_ID="digital-payments-52cac"
REGION="us-central1"
SERVICE_NAME="digital-payments-api"

echo "🧪 Testing Digital Payments App Deployment"
echo "=========================================="
echo ""

# Get service URL
if ! SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --format="value(status.url)" 2>/dev/null); then
    echo "❌ Service not found. Please deploy first using ./deploy.sh"
    exit 1
fi

echo "🌐 Service URL: $SERVICE_URL"
echo ""

# Function to test endpoint
test_endpoint() {
    local method=$1
    local endpoint=$2
    local description=$3
    local auth_header=$4
    local expected_status=$5
    
    echo -n "Testing $description... "
    
    if [ -n "$auth_header" ]; then
        response=$(curl -s -w "%{http_code}" -X $method -H "$auth_header" "$SERVICE_URL$endpoint" -o /dev/null)
    else
        response=$(curl -s -w "%{http_code}" -X $method "$SERVICE_URL$endpoint" -o /dev/null)
    fi
    
    if [ "$response" = "$expected_status" ]; then
        echo "✅ (HTTP $response)"
    else
        echo "❌ (HTTP $response, expected $expected_status)"
    fi
}

# Function to test endpoint with JSON response
test_json_endpoint() {
    local method=$1
    local endpoint=$2
    local description=$3
    local auth_header=$4
    
    echo -n "Testing $description... "
    
    if [ -n "$auth_header" ]; then
        response=$(curl -s -H "$auth_header" -H "Content-Type: application/json" "$SERVICE_URL$endpoint")
    else
        response=$(curl -s -H "Content-Type: application/json" "$SERVICE_URL$endpoint")
    fi
    
    if echo "$response" | grep -q "error\|Error"; then
        echo "❌"
        echo "   Response: $response"
    else
        echo "✅"
        echo "   Response: $response"
    fi
}

echo "🏥 Health Check Tests:"
echo "---------------------"
test_endpoint "GET" "/health" "Health endpoint" "" "200"

echo ""
echo "🔒 Authentication Tests:"
echo "------------------------"
test_endpoint "GET" "/pending-transfers/" "Pending transfers (no auth)" "" "401"
test_endpoint "GET" "/pending-transfers/" "Pending transfers (invalid auth)" "Authorization: Bearer invalid-token" "401"

echo ""
echo "📊 API Endpoint Tests:"
echo "---------------------"
# Note: These will return 401 without valid auth, which is expected
test_endpoint "POST" "/payments/send" "Send payment endpoint" "" "401"
test_endpoint "GET" "/pending-transfers/" "Get pending transfers" "" "401"
test_endpoint "GET" "/pending-transfers/by-email" "Get transfers by email" "" "401"

echo ""
echo "🌐 CORS and Headers Test:"
echo "-------------------------"
echo -n "Testing CORS headers... "
cors_response=$(curl -s -H "Origin: http://localhost:3000" -H "Access-Control-Request-Method: POST" -H "Access-Control-Request-Headers: Content-Type,Authorization" -X OPTIONS "$SERVICE_URL/health" -I)

if echo "$cors_response" | grep -q "Access-Control-Allow-Origin"; then
    echo "✅"
else
    echo "❌"
    echo "   CORS headers not found"
fi

echo ""
echo "🔍 Service Information:"
echo "----------------------"
echo "Service URL: $SERVICE_URL"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"

# Get service details
echo ""
echo "📋 Service Details:"
echo "------------------"
gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --format="table(
    metadata.name,
    status.url,
    status.latestReadyRevisionName,
    spec.template.spec.containers[0].image
)"

echo ""
echo "📈 Recent Logs (last 10 entries):"
echo "----------------------------------"
gcloud logs read "resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME" --limit=10 --project=$PROJECT_ID

echo ""
echo "✅ Testing Complete!"
echo ""
echo "📝 Notes:"
echo "- 401 responses for protected endpoints are expected without valid authentication"
echo "- To test with authentication, you'll need to implement proper token generation"
echo "- Monitor logs for any errors or issues"
echo ""
echo "🔗 Useful Commands:"
echo "- View logs: gcloud logs tail \"resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME\""
echo "- Service details: gcloud run services describe $SERVICE_NAME --region=$REGION"
echo "- Update service: ./deploy.sh $PROJECT_ID $REGION"