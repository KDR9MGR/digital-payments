# Digital Payments API - Monitoring Setup

## Overview
This document outlines the monitoring and logging setup for the Digital Payments API deployed on Google Cloud Run.

## Monitoring Components

### 1. Cloud Logging
- **Service**: Cloud Run service logs are automatically collected
- **Log Retention**: Logs are exported to BigQuery for long-term storage
- **Log Sink**: `digital-payments-logs` exports to BigQuery dataset `app_logs`

### 2. Log-Based Metrics
The following custom metrics have been created:

#### API Error Rate (`api_error_rate`)
- **Description**: Tracks error rate for the Digital Payments API
- **Filter**: Captures HTTP 4xx/5xx responses and ERROR severity logs
- **Usage**: Monitor application health and error trends

#### API Request Count (`api_request_count`)
- **Description**: Total requests to the Digital Payments API
- **Filter**: Captures all HTTP requests with request methods
- **Usage**: Monitor traffic patterns and usage

### 3. Built-in Cloud Run Metrics
Google Cloud Run automatically provides:
- **Request Count**: Total number of requests
- **Request Latency**: Response time distribution
- **Container CPU Utilization**: CPU usage metrics
- **Container Memory Utilization**: Memory usage metrics
- **Container Instance Count**: Number of running instances
- **Billable Instance Time**: Cost tracking

## Accessing Monitoring Data

### Cloud Console
1. **Monitoring Dashboard**: https://console.cloud.google.com/monitoring?project=digital-payments-52cac
2. **Cloud Run Metrics**: https://console.cloud.google.com/run/detail/us-central1/digital-payments-api?project=digital-payments-52cac
3. **Logs Explorer**: https://console.cloud.google.com/logs/query?project=digital-payments-52cac

### Key Monitoring Queries

#### View Recent Errors
```
resource.type="cloud_run_revision" 
AND resource.labels.service_name="digital-payments-api" 
AND (severity="ERROR" OR httpRequest.status>=400)
```

#### View All API Requests
```
resource.type="cloud_run_revision" 
AND resource.labels.service_name="digital-payments-api" 
AND httpRequest.requestMethod!=""
```

#### View Health Check Logs
```
resource.type="cloud_run_revision" 
AND resource.labels.service_name="digital-payments-api" 
AND httpRequest.requestUrl:"/health"
```

## Alerting Recommendations

### Critical Alerts
1. **Service Down**: Health check failures for > 5 minutes
2. **High Error Rate**: Error rate > 5% for > 10 minutes
3. **High Latency**: 95th percentile latency > 5 seconds for > 10 minutes

### Warning Alerts
1. **Increased Error Rate**: Error rate > 1% for > 15 minutes
2. **High CPU Usage**: CPU utilization > 80% for > 15 minutes
3. **High Memory Usage**: Memory utilization > 90% for > 10 minutes

## Performance Monitoring

### Key Metrics to Track
- **Availability**: Uptime percentage
- **Latency**: Response time percentiles (50th, 95th, 99th)
- **Throughput**: Requests per second
- **Error Rate**: Percentage of failed requests
- **Resource Usage**: CPU and memory utilization

### SLA Targets
- **Availability**: 99.9% uptime
- **Latency**: 95th percentile < 2 seconds
- **Error Rate**: < 0.1% for non-user errors

## Security Monitoring

### Events to Monitor
- Authentication failures
- Unauthorized access attempts
- Unusual traffic patterns
- Failed payment transactions
- Database connection errors

## Cost Monitoring
- Monitor Cloud Run billable instance time
- Track BigQuery storage costs for log retention
- Monitor Secret Manager API usage

## Next Steps
1. Set up email/SMS alerting policies
2. Create custom dashboards for business metrics
3. Implement application-level health checks
4. Set up synthetic monitoring for critical user journeys
5. Configure log-based alerting for security events

## Useful Commands

### View Recent Logs
```bash
gcloud run services logs read digital-payments-api \
  --region=us-central1 \
  --project=digital-payments-52cac \
  --limit=50
```

### List Log-Based Metrics
```bash
gcloud logging metrics list --project=digital-payments-52cac
```

### View Service Status
```bash
gcloud run services describe digital-payments-api \
  --region=us-central1 \
  --project=digital-payments-52cac
```