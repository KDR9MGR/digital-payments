# Digital Payments App - Google Cloud Platform Deployment Guide

This guide will help you deploy your Digital Payments application to Google Cloud Platform using Cloud Run, Cloud SQL, and Secret Manager.

## Prerequisites

- Google Cloud Platform account
- Google Cloud SDK (gcloud) installed and authenticated
- Docker installed (for local testing)
- Your Stripe and Plaid API credentials

## Deployment Steps

### 1. Authentication and Project Setup

```bash
# Authenticate with Google Cloud
gcloud auth login

# Set your project
gcloud config set project digital-payments-52cac

# Verify your project is set correctly
gcloud config get-value project
```

### 2. Set Up Secrets

First, create the secret placeholders:

```bash
./setup-secrets.sh
```

Then add your actual secret values:

```bash
./add-secret-values.sh
```

Or manually add secrets:

```bash
# Stripe Secret Key
echo "sk_live_your_stripe_secret_key" | gcloud secrets versions add stripe-secret-key --data-file=-

# Plaid Client ID
echo "your_plaid_client_id" | gcloud secrets versions add plaid-client-id --data-file=-

# Plaid Secret
echo "your_plaid_secret" | gcloud secrets versions add plaid-secret --data-file=-

# JWT Secret (generate a strong random string)
echo "your_jwt_secret_here" | gcloud secrets versions add jwt-secret --data-file=-
```

### 3. Set Up Database

Run the database setup script:

```bash
./setup-database.sh
```

This will:
- Create a Cloud SQL PostgreSQL instance
- Create the database and user
- Store the database URL in Secret Manager

### 4. Deploy to Cloud Run

Deploy your application:

```bash
./deploy.sh digital-payments-52cac us-central1
```

This will:
- Build your Docker image
- Push it to Google Container Registry
- Deploy to Cloud Run
- Output your service URL

### 5. Verify Deployment

After deployment, test your endpoints:

```bash
# Get your service URL
SERVICE_URL=$(gcloud run services describe digital-payments-backend --region=us-central1 --format="value(status.url)")

# Test health endpoint
curl $SERVICE_URL/health

# Test with authentication (replace with your actual token)
curl -H "Authorization: Bearer your-token" $SERVICE_URL/pending-transfers/
```

## Environment Variables

Your Cloud Run service will automatically have access to these environment variables from Secret Manager:

- `STRIPE_SECRET_KEY` - Your Stripe secret key
- `PLAID_CLIENT_ID` - Your Plaid client ID
- `PLAID_SECRET` - Your Plaid secret key
- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET` - JWT signing secret
- `PLAID_ENV` - Set to "production"
- `PORT` - Set to "8080"

## Database Schema

Your Go application should handle database migrations automatically. If you need to run manual migrations, you can connect to your Cloud SQL instance:

```bash
# Get connection details
gcloud sql instances describe digital-payments-db

# Connect using Cloud SQL Proxy (if needed)
gcloud sql connect digital-payments-db --user=app_user
```

## Monitoring and Logs

View your application logs:

```bash
# View recent logs
gcloud logs read "resource.type=cloud_run_revision AND resource.labels.service_name=digital-payments-backend" --limit=50

# Follow logs in real-time
gcloud logs tail "resource.type=cloud_run_revision AND resource.labels.service_name=digital-payments-backend"
```

## Updating Your Application

To update your application:

1. Make your code changes
2. Run the deployment script again:
   ```bash
   ./deploy.sh digital-payments-52cac us-central1
   ```

## Custom Domain (Optional)

To set up a custom domain:

1. Map your domain to Cloud Run:
   ```bash
   gcloud run domain-mappings create --service=digital-payments-backend --domain=api.yourdomain.com --region=us-central1
   ```

2. Update your DNS records as instructed by the command output

## Security Considerations

- All secrets are stored in Google Secret Manager
- Service account has minimal required permissions
- Cloud SQL instance is private by default
- HTTPS is enforced by Cloud Run

## Troubleshooting

### Common Issues

1. **Build failures**: Check your Dockerfile and ensure all dependencies are properly specified
2. **Secret access errors**: Verify your service account has the `secretmanager.secretAccessor` role
3. **Database connection issues**: Ensure your Cloud SQL instance is running and the connection string is correct

### Getting Help

- Check Cloud Run logs: `gcloud logs read`
- Verify secrets: `gcloud secrets list`
- Check service status: `gcloud run services describe digital-payments-backend --region=us-central1`

## Cost Optimization

- Cloud Run only charges for actual usage
- Cloud SQL can be stopped when not in use for development
- Consider using Cloud SQL's automatic scaling features

## Next Steps

1. Set up monitoring and alerting
2. Configure CI/CD pipeline
3. Set up staging environment
4. Implement backup strategy
5. Configure custom domain and SSL