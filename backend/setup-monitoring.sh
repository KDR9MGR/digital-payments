#!/bin/bash

# Setup monitoring and alerting for Digital Payments API
PROJECT_ID="digital-payments-52cac"
SERVICE_URL="https://digital-payments-api-1086070277189.us-central1.run.app"

echo "Setting up monitoring for Digital Payments API..."

# Enable required APIs
echo "Enabling monitoring APIs..."
gcloud services enable monitoring.googleapis.com --project=$PROJECT_ID
gcloud services enable logging.googleapis.com --project=$PROJECT_ID

# Create notification channel (email)
echo "Creating notification channel..."
cat > notification-channel.json << EOF
{
  "type": "email",
  "displayName": "Digital Payments Alerts",
  "description": "Email notifications for Digital Payments API",
  "labels": {
    "email_address": "admin@digitalpayments.com"
  }
}
EOF

# Create the notification channel
NOTIFICATION_CHANNEL=$(gcloud alpha monitoring channels create --channel-content-from-file=notification-channel.json --project=$PROJECT_ID --format="value(name)")
echo "Created notification channel: $NOTIFICATION_CHANNEL"

# Create alerting policy for service availability
echo "Creating alerting policy for service availability..."
cat > alerting-policy.json << EOF
{
  "displayName": "Digital Payments API Down",
  "documentation": {
    "content": "The Digital Payments API health check is failing",
    "mimeType": "text/markdown"
  },
  "conditions": [
    {
      "displayName": "Health check failure",
      "conditionThreshold": {
        "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"digital-payments-api\"",
        "comparison": "COMPARISON_LESS_THAN",
        "thresholdValue": 1,
        "duration": "300s",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_RATE",
            "crossSeriesReducer": "REDUCE_SUM"
          }
        ]
      }
    }
  ],
  "notificationChannels": ["$NOTIFICATION_CHANNEL"],
  "enabled": true
}
EOF

# Create the alerting policy
gcloud alpha monitoring policies create --policy-from-file=alerting-policy.json --project=$PROJECT_ID

# Create log-based metrics
echo "Creating log-based metrics..."

# Error rate metric
gcloud logging metrics create error_rate \
  --description="Rate of errors in Digital Payments API" \
  --log-filter='resource.type="cloud_run_revision" AND resource.labels.service_name="digital-payments-api" AND (severity="ERROR" OR httpRequest.status>=400)' \
  --project=$PROJECT_ID

# Response time metric  
gcloud logging metrics create response_time \
  --description="Response time for Digital Payments API" \
  --log-filter='resource.type="cloud_run_revision" AND resource.labels.service_name="digital-payments-api" AND httpRequest.latency!=""' \
  --project=$PROJECT_ID

echo "Setting up Cloud Run monitoring..."

# Create dashboard configuration
cat > dashboard-config.json << EOF
{
  "displayName": "Digital Payments API Dashboard",
  "mosaicLayout": {
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Request Count",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"digital-payments-api\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_RATE",
                      "crossSeriesReducer": "REDUCE_SUM"
                    }
                  }
                }
              }
            ]
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "xPos": 6,
        "widget": {
          "title": "Error Rate",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"digital-payments-api\" AND metric.type=\"logging.googleapis.com/user/error_rate\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_RATE",
                      "crossSeriesReducer": "REDUCE_SUM"
                    }
                  }
                }
              }
            ]
          }
        }
      }
    ]
  }
}
EOF

# Create the dashboard
gcloud monitoring dashboards create --config-from-file=dashboard-config.json --project=$PROJECT_ID

echo "Monitoring setup complete!"
echo "You can view your monitoring dashboard at:"
echo "https://console.cloud.google.com/monitoring/dashboards?project=$PROJECT_ID"

# Clean up temporary files
rm -f notification-channel.json alerting-policy.json dashboard-config.json

echo "Setup complete! Monitoring is now active for the Digital Payments API."