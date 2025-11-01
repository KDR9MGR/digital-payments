# Custom Domain Setup Instructions

## Prerequisites
1. You must own a domain name
2. Access to your domain's DNS settings

## Step 1: Update Domain Configuration
Edit the `setup-domain.sh` script and replace `api.digitalpayments.com` with your actual domain.

## Step 2: Run Domain Mapping
```bash
# Apply the domain mapping
gcloud run domain-mappings create \
  --service=digital-payments-api \
  --domain=YOUR_DOMAIN \
  --region=us-central1 \
  --project=digital-payments-52cac
```

## Step 3: Configure DNS
After running the domain mapping command, Google Cloud will provide DNS records that you need to add to your domain:

1. **A Record**: Points your domain to Google Cloud's IP addresses
2. **AAAA Record**: IPv6 equivalent (optional but recommended)
3. **CNAME Record**: For subdomain verification

Example DNS configuration:
```
Type: A
Name: api (or @ for root domain)
Value: 216.239.32.21, 216.239.34.21, 216.239.36.21, 216.239.38.21

Type: AAAA  
Name: api (or @ for root domain)
Value: 2001:4860:4802:32::15, 2001:4860:4802:34::15, 2001:4860:4802:36::15, 2001:4860:4802:38::15
```

## Step 4: SSL Certificate
Google Cloud Run automatically provisions and manages SSL certificates for custom domains. The certificate will be issued once:
1. Domain mapping is created
2. DNS records are properly configured
3. Domain verification is complete

## Step 5: Verify Setup
```bash
# Check domain mapping status
gcloud run domain-mappings describe YOUR_DOMAIN \
  --region=us-central1 \
  --project=digital-payments-52cac

# Test the domain
curl -I https://YOUR_DOMAIN/health
```

## Step 6: Update Application Configuration
Update your frontend application to use the new domain:
```
API_BASE_URL=https://YOUR_DOMAIN
```

## Troubleshooting

### Common Issues
1. **DNS Propagation**: DNS changes can take up to 48 hours to propagate globally
2. **Certificate Provisioning**: SSL certificates may take 10-60 minutes to provision
3. **Domain Verification**: Ensure all required DNS records are correctly configured

### Verification Commands
```bash
# Check DNS resolution
nslookup YOUR_DOMAIN

# Check SSL certificate
openssl s_client -connect YOUR_DOMAIN:443 -servername YOUR_DOMAIN

# Check domain mapping status
gcloud run domain-mappings list --project=digital-payments-52cac
```

### Support
- Google Cloud Run Domain Mapping: https://cloud.google.com/run/docs/mapping-custom-domains
- SSL Certificate Management: https://cloud.google.com/run/docs/securing/using-https
