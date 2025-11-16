package main

import (
    "context"
    "fmt"
    "log"
    "os"

    "github.com/stripe/stripe-go/v76"
    "github.com/stripe/stripe-go/v76/account"
    "github.com/stripe/stripe-go/v76/accountlink"
    "github.com/stripe/stripe-go/v76/customer"
    "github.com/stripe/stripe-go/v76/paymentintent"
    "github.com/stripe/stripe-go/v76/paymentmethod"
    "github.com/stripe/stripe-go/v76/setupintent"
    "github.com/stripe/stripe-go/v76/transfer"
    "github.com/stripe/stripe-go/v76/webhook"
)

type StripeClient struct {
	SecretKey string
	Environment string
}

type StripeCustomer struct {
	ID       string `json:"id"`
	Email    string `json:"email"`
	Name     string `json:"name"`
	Metadata map[string]string `json:"metadata"`
}

type StripePaymentIntent struct {
	ID               string `json:"id"`
	Amount           int64  `json:"amount"`
	Currency         string `json:"currency"`
	Status           string `json:"status"`
	ClientSecret     string `json:"client_secret"`
	PaymentMethodID  string `json:"payment_method_id"`
	CustomerID       string `json:"customer_id"`
}

type StripeTransfer struct {
	ID          string `json:"id"`
	Amount      int64  `json:"amount"`
	Currency    string `json:"currency"`
	Destination string `json:"destination"`
	Status      string `json:"status"`
}

type StripeConnectAccountStatus struct {
    ID              string `json:"id"`
    ChargesEnabled  bool   `json:"charges_enabled"`
    PayoutsEnabled  bool   `json:"payouts_enabled"`
}

// NewStripeClient creates a new Stripe client
func NewStripeClient() (*StripeClient, error) {
	secretKey := os.Getenv("STRIPE_SECRET_KEY")
	if secretKey == "" {
		return nil, fmt.Errorf("STRIPE_SECRET_KEY environment variable is required")
	}

	environment := os.Getenv("STRIPE_ENVIRONMENT")
	if environment == "" {
		environment = "test"
	}

	// Set the Stripe API key
	stripe.Key = secretKey

	client := &StripeClient{
		SecretKey:   secretKey,
		Environment: environment,
	}

	return client, nil
}

// CreateCustomer creates a new Stripe customer
func (sc *StripeClient) CreateCustomer(ctx context.Context, email, name, userID string) (*StripeCustomer, error) {
	params := &stripe.CustomerParams{
		Email: stripe.String(email),
		Name:  stripe.String(name),
		Metadata: map[string]string{
			"user_id": userID,
		},
	}

	c, err := customer.New(params)
	if err != nil {
		return nil, fmt.Errorf("failed to create customer: %w", err)
	}

	return &StripeCustomer{
		ID:       c.ID,
		Email:    c.Email,
		Name:     c.Name,
		Metadata: c.Metadata,
	}, nil
}

// CreateConnectAccount creates a Stripe Express connected account for a user
func (sc *StripeClient) CreateConnectAccount(ctx context.Context, email, userID, country string) (string, error) {
    if country == "" {
        country = "US"
    }

    params := &stripe.AccountParams{
        Type:    stripe.String(string(stripe.AccountTypeExpress)),
        Country: stripe.String(country),
        Email:   stripe.String(email),
        BusinessType: stripe.String(string(stripe.AccountBusinessTypeIndividual)),
        Metadata: map[string]string{
            "user_id": userID,
        },
    }

    // Request capabilities needed for charging and transferring
    params.Capabilities = &stripe.AccountCapabilitiesParams{
        CardPayments: &stripe.AccountCapabilitiesCardPaymentsParams{Requested: stripe.Bool(true)},
        Transfers:    &stripe.AccountCapabilitiesTransfersParams{Requested: stripe.Bool(true)},
    }

    acc, err := account.New(params)
    if err != nil {
        return "", fmt.Errorf("failed to create connect account: %w", err)
    }

    return acc.ID, nil
}

// CreateAccountLink returns an onboarding link for a connected account
func (sc *StripeClient) CreateAccountLink(ctx context.Context, accountID string) (string, error) {
    refreshURL := os.Getenv("STRIPE_CONNECT_REFRESH_URL")
    returnURL := os.Getenv("STRIPE_CONNECT_REDIRECT_URL")
    if refreshURL == "" || returnURL == "" {
        return "", fmt.Errorf("STRIPE_CONNECT_REFRESH_URL and STRIPE_CONNECT_REDIRECT_URL must be set")
    }

    params := &stripe.AccountLinkParams{
        Account:    stripe.String(accountID),
        RefreshURL: stripe.String(refreshURL),
        ReturnURL:  stripe.String(returnURL),
        Type:       stripe.String("account_onboarding"),
    }

    link, err := accountlink.New(params)
    if err != nil {
        return "", fmt.Errorf("failed to create account link: %w", err)
    }
    return link.URL, nil
}

// GetConnectAccountStatus fetches charges/payouts status
func (sc *StripeClient) GetConnectAccountStatus(ctx context.Context, accountID string) (*StripeConnectAccountStatus, error) {
    acc, err := account.GetByID(accountID, nil)
    if err != nil {
        return nil, fmt.Errorf("failed to get account: %w", err)
    }
    return &StripeConnectAccountStatus{
        ID:             acc.ID,
        ChargesEnabled: acc.ChargesEnabled,
        PayoutsEnabled: acc.PayoutsEnabled,
    }, nil
}

// CreatePaymentIntent creates a payment intent for ACH transfers
func (sc *StripeClient) CreatePaymentIntent(ctx context.Context, amount int64, currency, customerID, paymentMethodID string, metadata map[string]string) (*StripePaymentIntent, error) {
    params := &stripe.PaymentIntentParams{
        Amount:   stripe.Int64(amount),
        Currency: stripe.String(currency),
        Customer: stripe.String(customerID),
        PaymentMethodTypes: stripe.StringSlice([]string{
            "us_bank_account",
        }),
        Metadata: map[string]string{
            "integration": "plaid_stripe",
        },
    }
    // Merge additional metadata
    if metadata != nil {
        for k, v := range metadata {
            params.Metadata[k] = v
        }
    }

	if paymentMethodID != "" {
		params.PaymentMethod = stripe.String(paymentMethodID)
		params.ConfirmationMethod = stripe.String("manual")
		params.Confirm = stripe.Bool(true)
	}

    pi, err := paymentintent.New(params)
	if err != nil {
		return nil, fmt.Errorf("failed to create payment intent: %w", err)
	}

	return &StripePaymentIntent{
		ID:              pi.ID,
		Amount:          pi.Amount,
		Currency:        string(pi.Currency),
		Status:          string(pi.Status),
		ClientSecret:    pi.ClientSecret,
		PaymentMethodID: paymentMethodID,
		CustomerID:      customerID,
	}, nil
}

// CreateSetupIntent creates a setup intent for saving payment methods
func (sc *StripeClient) CreateSetupIntent(ctx context.Context, customerID string) (*stripe.SetupIntent, error) {
	params := &stripe.SetupIntentParams{
		Customer: stripe.String(customerID),
		PaymentMethodTypes: stripe.StringSlice([]string{
			"us_bank_account",
		}),
		Usage: stripe.String("off_session"),
	}

	si, err := setupintent.New(params)
	if err != nil {
		return nil, fmt.Errorf("failed to create setup intent: %w", err)
	}

	return si, nil
}

// CreatePaymentMethodFromPlaid creates a Stripe payment method using Plaid account data
func (sc *StripeClient) CreatePaymentMethodFromPlaid(ctx context.Context, accountID, routingNumber, accountNumber, accountType string) (*stripe.PaymentMethod, error) {
	params := &stripe.PaymentMethodParams{
		Type: stripe.String("us_bank_account"),
		USBankAccount: &stripe.PaymentMethodUSBankAccountParams{
			RoutingNumber: stripe.String(routingNumber),
			AccountNumber: stripe.String(accountNumber),
			AccountType:   stripe.String(accountType), // "checking" or "savings"
		},
		Metadata: map[string]string{
			"plaid_account_id": accountID,
			"verification":     "plaid",
		},
	}

	pm, err := paymentmethod.New(params)
	if err != nil {
		return nil, fmt.Errorf("failed to create payment method: %w", err)
	}

	return pm, nil
}

// ProcessTransfer processes a transfer between accounts (optionally grouped)
func (sc *StripeClient) ProcessTransfer(ctx context.Context, amount int64, currency, destination, transferGroup string) (*StripeTransfer, error) {
    params := &stripe.TransferParams{
        Amount:      stripe.Int64(amount),
        Currency:    stripe.String(currency),
        Destination: stripe.String(destination),
    }
    if transferGroup != "" {
        params.TransferGroup = stripe.String(transferGroup)
    }

    t, err := transfer.New(params)
    if err != nil {
        return nil, fmt.Errorf("failed to process transfer: %w", err)
    }

    return &StripeTransfer{
        ID:          t.ID,
        Amount:      t.Amount,
        Currency:    string(t.Currency),
        Destination: t.Destination.ID,
        Status:      string(t.Object),
    }, nil
}

// ConfirmPaymentIntent confirms a payment intent
func (sc *StripeClient) ConfirmPaymentIntent(ctx context.Context, paymentIntentID string) (*StripePaymentIntent, error) {
	params := &stripe.PaymentIntentConfirmParams{}
	
	pi, err := paymentintent.Confirm(paymentIntentID, params)
	if err != nil {
		return nil, fmt.Errorf("failed to confirm payment intent: %w", err)
	}

	return &StripePaymentIntent{
		ID:           pi.ID,
		Amount:       pi.Amount,
		Currency:     string(pi.Currency),
		Status:       string(pi.Status),
		ClientSecret: pi.ClientSecret,
	}, nil
}

// GetPaymentIntent retrieves a payment intent
func (sc *StripeClient) GetPaymentIntent(ctx context.Context, paymentIntentID string) (*StripePaymentIntent, error) {
	pi, err := paymentintent.Get(paymentIntentID, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get payment intent: %w", err)
	}

	return &StripePaymentIntent{
		ID:           pi.ID,
		Amount:       pi.Amount,
		Currency:     string(pi.Currency),
		Status:       string(pi.Status),
		ClientSecret: pi.ClientSecret,
	}, nil
}

// ValidateWebhook validates a Stripe webhook signature
func (sc *StripeClient) ValidateWebhook(payload []byte, signature string) (stripe.Event, error) {
	webhookSecret := os.Getenv("STRIPE_WEBHOOK_SECRET")
	if webhookSecret == "" {
		return stripe.Event{}, fmt.Errorf("STRIPE_WEBHOOK_SECRET not configured")
	}

	event, err := webhook.ConstructEvent(payload, signature, webhookSecret)
	if err != nil {
		return stripe.Event{}, fmt.Errorf("failed to validate webhook: %w", err)
	}

	return event, nil
}

// LogAPIInteraction logs Stripe API interactions for debugging
func (sc *StripeClient) LogAPIInteraction(ctx context.Context, operation, userID string, success bool, details string) {
	status := "success"
	if !success {
		status = "error"
	}
	
	log.Printf("[STRIPE] %s - User: %s, Status: %s, Details: %s", 
		operation, userID, status, details)
}
// CreatePaymentIntentWithIdempotency creates a payment intent with optional idempotency key
func (sc *StripeClient) CreatePaymentIntentWithIdempotency(ctx context.Context, amount int64, currency, customerID, paymentMethodID string, metadata map[string]string, idempotencyKey string) (*StripePaymentIntent, error) {
    params := &stripe.PaymentIntentParams{
        Amount:   stripe.Int64(amount),
        Currency: stripe.String(currency),
        Customer: stripe.String(customerID),
        PaymentMethodTypes: stripe.StringSlice([]string{"card"}),
        Metadata: map[string]string{"integration": "stripe_only"},
    }
    if metadata != nil {
        for k, v := range metadata { params.Metadata[k] = v }
    }
    if paymentMethodID != "" {
        params.PaymentMethod = stripe.String(paymentMethodID)
        params.ConfirmationMethod = stripe.String("manual")
        params.Confirm = stripe.Bool(true)
    }
    if idempotencyKey != "" { params.SetIdempotencyKey(idempotencyKey) }

    pi, err := paymentintent.New(params)
    if err != nil { return nil, fmt.Errorf("failed to create payment intent: %w", err) }
    return &StripePaymentIntent{ ID: pi.ID, Amount: pi.Amount, Currency: string(pi.Currency), Status: string(pi.Status), ClientSecret: pi.ClientSecret, PaymentMethodID: paymentMethodID, CustomerID: customerID }, nil
}

// ProcessTransferWithIdempotency creates a transfer with idempotency key
func (sc *StripeClient) ProcessTransferWithIdempotency(ctx context.Context, amount int64, currency, destination, transferGroup, idempotencyKey string) (*StripeTransfer, error) {
    params := &stripe.TransferParams{ Amount: stripe.Int64(amount), Currency: stripe.String(currency), Destination: stripe.String(destination) }
    if transferGroup != "" { params.TransferGroup = stripe.String(transferGroup) }
    if idempotencyKey != "" { params.SetIdempotencyKey(idempotencyKey) }
    t, err := transfer.New(params)
    if err != nil { return nil, fmt.Errorf("failed to process transfer: %w", err) }
    return &StripeTransfer{ ID: t.ID, Amount: t.Amount, Currency: string(t.Currency), Destination: t.Destination.ID, Status: string(t.Object) }, nil
}