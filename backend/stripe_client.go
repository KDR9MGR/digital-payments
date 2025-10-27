package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/stripe/stripe-go/v76"
	"github.com/stripe/stripe-go/v76/account"
	"github.com/stripe/stripe-go/v76/accountlink"
	"github.com/stripe/stripe-go/v76/balance"
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

type StripeCharge struct {
	ID          string `json:"id"`
	Amount      int64  `json:"amount"`
	Currency    string `json:"currency"`
	Source      string `json:"source"`
	Status      string `json:"status"`
	Description string `json:"description"`
}

type PaymentTransaction struct {
	ID                string `json:"id"`
	SenderID          string `json:"sender_id"`
	ReceiverID        string `json:"receiver_id"`
	ReceiverEmail     string `json:"receiver_email"`
	Amount            int64  `json:"amount"`
	Currency          string `json:"currency"`
	Description       string `json:"description"`
	Status            string `json:"status"` // pending, processing, completed, failed
	ChargeID          string `json:"charge_id,omitempty"`
	TransferID        string `json:"transfer_id,omitempty"`
	CreatedAt         int64  `json:"created_at"`
	CompletedAt       int64  `json:"completed_at,omitempty"`
}

type StripeConnectAccount struct {
	ID                string                 `json:"id"`
	Type              string                 `json:"type"`
	Country           string                 `json:"country"`
	Email             string                 `json:"email"`
	ChargesEnabled    bool                   `json:"charges_enabled"`
	PayoutsEnabled    bool                   `json:"payouts_enabled"`
	DetailsSubmitted  bool                   `json:"details_submitted"`
	Requirements      *AccountRequirements   `json:"requirements,omitempty"`
	Individual        *IndividualInfo        `json:"individual,omitempty"`
	Business          *BusinessInfo          `json:"business,omitempty"`
	Metadata          map[string]string      `json:"metadata"`
}

type AccountRequirements struct {
	CurrentlyDue        []string `json:"currently_due"`
	EventuallyDue       []string `json:"eventually_due"`
	PastDue             []string `json:"past_due"`
	PendingVerification []string `json:"pending_verification"`
	DisabledReason      string   `json:"disabled_reason,omitempty"`
}

type IndividualInfo struct {
	FirstName   string   `json:"first_name,omitempty"`
	LastName    string   `json:"last_name,omitempty"`
	Email       string   `json:"email,omitempty"`
	Phone       string   `json:"phone,omitempty"`
	DOB         *DOB     `json:"dob,omitempty"`
	Address     *Address `json:"address,omitempty"`
	SSNLast4    string   `json:"ssn_last_4,omitempty"`
	IDNumber    string   `json:"id_number,omitempty"`
}

type BusinessInfo struct {
	Name        string   `json:"name,omitempty"`
	TaxID       string   `json:"tax_id,omitempty"`
	Address     *Address `json:"address,omitempty"`
	Phone       string   `json:"phone,omitempty"`
	URL         string   `json:"url,omitempty"`
	Description string   `json:"description,omitempty"`
}

type DOB struct {
	Day   int `json:"day"`
	Month int `json:"month"`
	Year  int `json:"year"`
}

type Address struct {
	Line1      string `json:"line1,omitempty"`
	Line2      string `json:"line2,omitempty"`
	City       string `json:"city,omitempty"`
	State      string `json:"state,omitempty"`
	PostalCode string `json:"postal_code,omitempty"`
	Country    string `json:"country,omitempty"`
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

// CreatePaymentIntent creates a payment intent for ACH transfers
func (sc *StripeClient) CreatePaymentIntent(ctx context.Context, amount int64, currency, customerID, paymentMethodID string) (*StripePaymentIntent, error) {
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

// ProcessTransfer processes a transfer between accounts
func (sc *StripeClient) ProcessTransfer(ctx context.Context, amount int64, currency, destination string) (*StripeTransfer, error) {
	params := &stripe.TransferParams{
		Amount:      stripe.Int64(amount),
		Currency:    stripe.String(currency),
		Destination: stripe.String(destination),
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
		status = "failed"
	}
	log.Printf("Stripe API - Operation: %s, User: %s, Status: %s, Details: %s", operation, userID, status, details)
}

// CreateConnectAccount creates a new Stripe Connect custom account
func (sc *StripeClient) CreateConnectAccount(ctx context.Context, email, userID string, accountType string) (*StripeConnectAccount, error) {
	params := &stripe.AccountParams{
		Type:    stripe.String("custom"),
		Country: stripe.String("US"),
		Email:   stripe.String(email),
		Capabilities: &stripe.AccountCapabilitiesParams{
			CardPayments: &stripe.AccountCapabilitiesCardPaymentsParams{
				Requested: stripe.Bool(true),
			},
			Transfers: &stripe.AccountCapabilitiesTransfersParams{
				Requested: stripe.Bool(true),
			},
		},
		BusinessType: stripe.String(accountType), // "individual" or "company"
		Metadata: map[string]string{
			"user_id": userID,
			"created_by": "app_registration",
		},
	}

	acc, err := account.New(params)
	if err != nil {
		return nil, fmt.Errorf("failed to create Stripe Connect account: %w", err)
	}

	return &StripeConnectAccount{
		ID:               acc.ID,
		Type:             string(acc.Type),
		Country:          acc.Country,
		Email:            acc.Email,
		ChargesEnabled:   acc.ChargesEnabled,
		PayoutsEnabled:   acc.PayoutsEnabled,
		DetailsSubmitted: acc.DetailsSubmitted,
		Metadata:         acc.Metadata,
	}, nil
}

// GetConnectAccount retrieves a Stripe Connect account by ID
func (sc *StripeClient) GetConnectAccount(ctx context.Context, accountID string) (*StripeConnectAccount, error) {
	acc, err := account.GetByID(accountID, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve Stripe Connect account: %w", err)
	}

	connectAccount := &StripeConnectAccount{
		ID:               acc.ID,
		Type:             string(acc.Type),
		Country:          acc.Country,
		Email:            acc.Email,
		ChargesEnabled:   acc.ChargesEnabled,
		PayoutsEnabled:   acc.PayoutsEnabled,
		DetailsSubmitted: acc.DetailsSubmitted,
		Metadata:         acc.Metadata,
	}

	// Map requirements if they exist
	if acc.Requirements != nil {
		connectAccount.Requirements = &AccountRequirements{
			CurrentlyDue:        acc.Requirements.CurrentlyDue,
			EventuallyDue:       acc.Requirements.EventuallyDue,
			PastDue:             acc.Requirements.PastDue,
			PendingVerification: acc.Requirements.PendingVerification,
			DisabledReason:      string(acc.Requirements.DisabledReason),
		}
	}

	return connectAccount, nil
}

// UpdateConnectAccountIndividual updates individual information for a Stripe Connect account
func (sc *StripeClient) UpdateConnectAccountIndividual(ctx context.Context, accountID string, individual *IndividualInfo) (*StripeConnectAccount, error) {
	params := &stripe.AccountParams{
		Individual: &stripe.PersonParams{
			FirstName: stripe.String(individual.FirstName),
			LastName:  stripe.String(individual.LastName),
			Email:     stripe.String(individual.Email),
			Phone:     stripe.String(individual.Phone),
		},
	}

	// Add DOB if provided
	if individual.DOB != nil {
		params.Individual.DOB = &stripe.PersonDOBParams{
			Day:   stripe.Int64(int64(individual.DOB.Day)),
			Month: stripe.Int64(int64(individual.DOB.Month)),
			Year:  stripe.Int64(int64(individual.DOB.Year)),
		}
	}

	// Add address if provided
	if individual.Address != nil {
		params.Individual.Address = &stripe.AddressParams{
			Line1:      stripe.String(individual.Address.Line1),
			Line2:      stripe.String(individual.Address.Line2),
			City:       stripe.String(individual.Address.City),
			State:      stripe.String(individual.Address.State),
			PostalCode: stripe.String(individual.Address.PostalCode),
			Country:    stripe.String(individual.Address.Country),
		}
	}

	// Add SSN last 4 if provided
	if individual.SSNLast4 != "" {
		params.Individual.SSNLast4 = stripe.String(individual.SSNLast4)
	}

	acc, err := account.Update(accountID, params)
	if err != nil {
		return nil, fmt.Errorf("failed to update Stripe Connect account individual info: %w", err)
	}

	return sc.GetConnectAccount(ctx, acc.ID)
}

// CreateAccountLink creates an account link for onboarding
func (sc *StripeClient) CreateAccountLink(ctx context.Context, accountID, refreshURL, returnURL string) (string, error) {
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

// DeleteConnectAccount deletes a Stripe Connect account
func (sc *StripeClient) DeleteConnectAccount(ctx context.Context, accountID string) error {
	_, err := account.Del(accountID, nil)
	if err != nil {
		return fmt.Errorf("failed to delete Stripe Connect account: %w", err)
	}
	return nil
}

// ProcessSendMoneyTransaction handles the complete send money flow:
// For now, we'll simulate the flow by directly transferring from sender to receiver
// In a real implementation, you would need payment methods attached to accounts
func (sc *StripeClient) ProcessSendMoneyTransaction(ctx context.Context, senderConnectID, receiverConnectID string, amount int64, currency, description string) (*PaymentTransaction, error) {
	transactionID := fmt.Sprintf("txn_%d", time.Now().Unix())
	
	transaction := &PaymentTransaction{
		ID:          transactionID,
		SenderID:    senderConnectID,
		ReceiverID:  receiverConnectID,
		Amount:      amount,
		Currency:    currency,
		Description: description,
		Status:      "processing",
		CreatedAt:   time.Now().Unix(),
	}

	// For this implementation, we'll transfer funds from platform to receiver
	// In a real scenario, you would first collect funds from sender's payment method
	// then transfer to receiver's connected account
	transfer, err := sc.ProcessTransfer(ctx, amount, currency, receiverConnectID)
	if err != nil {
		transaction.Status = "failed"
		return transaction, fmt.Errorf("failed to transfer to receiver: %w", err)
	}
	
	transaction.TransferID = transfer.ID
	transaction.Status = "completed"
	transaction.CompletedAt = time.Now().Unix()

	return transaction, nil
}

// GetAccountBalance retrieves the balance of a connected account
func (sc *StripeClient) GetAccountBalance(ctx context.Context, accountID string) (*stripe.Balance, error) {
	params := &stripe.BalanceParams{}
	params.SetStripeAccount(accountID)
	
	balance, err := balance.Get(params)
	if err != nil {
		return nil, fmt.Errorf("failed to get account balance: %w", err)
	}
	
	return balance, nil
}