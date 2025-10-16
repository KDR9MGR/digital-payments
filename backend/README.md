# # Digital Payments Backend

A robust Go backend service for digital payments using the Sila Money API.

## Features

- **Sila Integration**: Full integration with Sila Money API using the official Go SDK
- **JWT Authentication**: Secure user authentication with JWT tokens
- **Account Management**: Create and manage Sila accounts
- **KYC Processing**: Handle Know Your Customer verification
- **Payment Methods**: Manage bank accounts and payment sources
- **Transfers**: Process money transfers and payments
- **Webhooks**: Handle real-time event notifications from payment providers
- **CORS Support**: Cross-origin resource sharing for web applications

## Prerequisites

- Go 1.21 or higher
- Sila Money account with API credentials
- Environment variables configured

## Setup

1. **Clone and navigate to backend directory**:
   ```bash
   cd backend
   ```

2. **Install dependencies**:
   ```bash
   go mod tidy
   ```

3. **Configure environment variables**:
   ```bash
   cp .env.example .env
   # Edit .env with your actual values
   ```

4. **Required environment variables**:
   ```env
   SILA_APP_HANDLE=your_app_handle_here
   SILA_PRIVATE_KEY=your_private_key_here
   SILA_BASE_URL=https://sandbox.silamoney.com
   JWT_SECRET=your_jwt_secret_here
   PORT=8080
   ```

## Running the Service

### Development
```bash
go run .
```

### Production
```bash
go build -o digital-payments-backend
./digital-payments-backend
```

## API Endpoints

### Authentication
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/register` - User registration

### Account Management
- `POST /api/v1/accounts` - Create Sila account
- `GET /api/v1/accounts/:accountID` - Get account details
- `PATCH /api/v1/accounts/:accountID` - Update account

### KYC (Know Your Customer)
- `POST /api/v1/kyc` - Submit KYC information
- `GET /api/v1/kyc/:accountID` - Get KYC status

### Payment Methods
- `POST /api/v1/payment-methods` - Add payment method
- `GET /api/v1/payment-methods` - Get payment methods
- `DELETE /api/v1/payment-methods/:paymentMethodID` - Remove payment method

### Transfers
- `POST /api/v1/transfers` - Create transfer
- `GET /api/v1/transfers/:transferID` - Get transfer details
- `GET /api/v1/transfers` - Get all transfers

### Webhooks
- `POST /api/v1/webhooks/sila` - Handle Sila webhooks

### Health Check
- `GET /api/v1/health` - Service health status

## Authentication

All protected endpoints require a JWT token in the Authorization header:
```
Authorization: Bearer <your-jwt-token>
```

## Example Usage

### Create Account
```bash
curl -X POST http://localhost:8080/api/v1/accounts \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your-jwt-token>" \
  -d '{
    "accountType": "individual",
    "profile": {
      "individual": {
        "name": {
          "first": "John",
          "last": "Doe"
        },
        "email": "john.doe@example.com",
        "phone": {
          "number": "+1234567890"
        },
        "address": {
          "addressLine1": "123 Main St",
          "city": "San Francisco",
          "stateOrProvince": "CA",
          "postalCode": "94105",
          "country": "US"
        },
        "birthDate": {
          "day": 15,
          "month": 6,
          "year": 1990
        },
        "governmentID": {
          "ssn": {
            "full": "123-45-6789"
          }
        }
      }
    }
  }'
```

## Error Handling

The API returns standard HTTP status codes and JSON error responses:

```json
{
  "error": "Error description",
  "details": "Additional error details"
}
```

## Security

- JWT tokens for authentication
- CORS protection
- Input validation
- Secure credential handling
- Environment-based configuration

## Development

### Project Structure
```
backend/
├── main.go              # Application entry point
├── sila_client.go       # Sila API client wrapper
├── stripe_client.go     # Stripe API client wrapper
├── plaid_client.go      # Plaid API client wrapper
├── middleware.go        # Authentication and CORS middleware
├── handlers.go          # API route handlers
├── go.mod              # Go module dependencies
├── .env.example        # Environment variables template
└── README.md           # This file
```

### Adding New Features

1. Add new routes in `main.go`
2. Implement handlers in `handlers.go`
3. Update middleware if needed
4. Test with your Flutter app

## Integration with Flutter App

This backend service is designed to work with the Flutter digital payments app. Update your Flutter app's API endpoints to point to this Go service:

```dart
const String baseUrl = 'http://localhost:8080/api/v1';
```

## Deployment

### Docker (Recommended)
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o digital-payments-backend

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/digital-payments-backend .
CMD ["./digital-payments-backend"]
```

### Environment Variables for Production
- Use secure JWT secrets
- Set appropriate CORS origins
- Use production Sila API URLs
- Configure proper logging

## Support

For issues related to:
- Sila API: Check [Sila Documentation](https://docs.silamoney.com/)
- Stripe API: Check [Stripe Documentation](https://stripe.com/docs)
- Plaid API: Check [Plaid Documentation](https://plaid.com/docs/)
- This backend: Create an issue in your project repository