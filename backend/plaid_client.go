package main

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"os"
	"time"

	"github.com/plaid/plaid-go/v11/plaid"
)

// PlaidClient represents the Plaid API client for P2P payment orchestration
type PlaidClient struct {
	client      *plaid.APIClient
	clientID    string
	secret      string
	publicKey   string
	environment plaid.Environment
	products    []plaid.Products
	countryCodes []plaid.CountryCode
}

// PlaidAccount represents a connected bank account
type PlaidAccount struct {
	AccountID       string  `json:"account_id"`
	Name           string  `json:"name"`
	Type           string  `json:"type"`
	Subtype        string  `json:"subtype"`
	Balance        float64 `json:"balance"`
	AvailableBalance float64 `json:"available_balance"`
	RoutingNumber  string  `json:"routing_number,omitempty"`
	AccountNumber  string  `json:"account_number,omitempty"`
	IsVerified     bool    `json:"is_verified"`
	AccessToken    string  `json:"-"` // Never expose in JSON
	Numbers        *plaid.AccountBase `json:"-"` // Account numbers from auth
	Mask           string  `json:"mask,omitempty"` // Last 4 digits
}

// PlaidUser represents a user with connected accounts
type PlaidUser struct {
	UserID      string         `json:"user_id"`
	AccessToken string         `json:"-"` // Never expose in JSON
	ItemID      string         `json:"item_id"`
	Accounts    []PlaidAccount `json:"accounts"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
}

// PlaidTransaction represents a transaction from Plaid
type PlaidTransaction struct {
	TransactionID string    `json:"transaction_id"`
	AccountID     string    `json:"account_id"`
	Amount        float64   `json:"amount"`
	Date          time.Time `json:"date"`
	Name          string    `json:"name"`
	Category      []string  `json:"category"`
	Pending       bool      `json:"pending"`
}

// PlaidTransfer represents a P2P transfer request
type PlaidTransfer struct {
	TransferID      string    `json:"transfer_id"`
	SenderUserID    string    `json:"sender_user_id"`
	ReceiverUserID  string    `json:"receiver_user_id"`
	Amount          float64   `json:"amount"`
	Description     string    `json:"description"`
	Status          string    `json:"status"`
	CreatedAt       time.Time `json:"created_at"`
	CompletedAt     *time.Time `json:"completed_at,omitempty"`
	ProcessorTxnID  string    `json:"processor_txn_id,omitempty"`
}

// NewPlaidClient creates a new Plaid client instance
func NewPlaidClient() (*PlaidClient, error) {
	clientID := os.Getenv("PLAID_CLIENT_ID")
	secret := os.Getenv("PLAID_SECRET")
	publicKey := os.Getenv("PLAID_PUBLIC_KEY")
	envStr := os.Getenv("PLAID_ENVIRONMENT")
	
	if clientID == "" || secret == "" {
		return nil, fmt.Errorf("PLAID_CLIENT_ID and PLAID_SECRET are required")
	}

	// Parse environment
	var environment plaid.Environment
	switch envStr {
	case "sandbox":
		environment = plaid.Sandbox
	case "development":
		environment = plaid.Development
	case "production":
		environment = plaid.Production
	default:
		environment = plaid.Sandbox // Default to sandbox for safety
	}

	// Configure Plaid client
	configuration := plaid.NewConfiguration()
	configuration.AddDefaultHeader("PLAID-CLIENT-ID", clientID)
	configuration.AddDefaultHeader("PLAID-SECRET", secret)
	configuration.UseEnvironment(environment)

	client := plaid.NewAPIClient(configuration)

	// Parse products
	products := []plaid.Products{
		plaid.PRODUCTS_AUTH,
		plaid.PRODUCTS_TRANSACTIONS,
		plaid.PRODUCTS_IDENTITY,
	}

	// Parse country codes
	countryCodes := []plaid.CountryCode{
		plaid.COUNTRYCODE_US,
		plaid.COUNTRYCODE_CA,
	}

	return &PlaidClient{
		client:       client,
		clientID:     clientID,
		secret:       secret,
		publicKey:    publicKey,
		environment:  environment,
		products:     products,
		countryCodes: countryCodes,
	}, nil
}

// CreateLinkToken creates a link token for Plaid Link flow
func (pc *PlaidClient) CreateLinkToken(ctx context.Context, userID string) (string, error) {
	user := plaid.LinkTokenCreateRequestUser{
		ClientUserId: userID,
	}

	request := plaid.NewLinkTokenCreateRequest(
		"Digital Payments App",
		"en",
		pc.countryCodes,
		user,
	)
	request.SetProducts(pc.products)

	// Add webhook URL if configured
	if webhookURL := os.Getenv("PLAID_WEBHOOK_URL"); webhookURL != "" {
		request.SetWebhook(webhookURL)
	}

	response, _, err := pc.client.PlaidApi.LinkTokenCreate(ctx).LinkTokenCreateRequest(*request).Execute()
	if err != nil {
		return "", fmt.Errorf("failed to create link token: %w", err)
	}

	return response.GetLinkToken(), nil
}

// ExchangePublicToken exchanges a public token for an access token
func (pc *PlaidClient) ExchangePublicToken(ctx context.Context, publicToken string) (string, string, error) {
	request := plaid.NewItemPublicTokenExchangeRequest(publicToken)
	
	response, _, err := pc.client.PlaidApi.ItemPublicTokenExchange(ctx).ItemPublicTokenExchangeRequest(*request).Execute()
	if err != nil {
		return "", "", fmt.Errorf("failed to exchange public token: %w", err)
	}

	accessToken := response.GetAccessToken()
	itemID := response.GetItemId()

	// Encrypt and store access token securely
	encryptedToken, err := pc.encryptToken(accessToken)
	if err != nil {
		log.Printf("Warning: Failed to encrypt access token: %v", err)
		// Continue with unencrypted token for now, but log the issue
	} else {
		accessToken = encryptedToken
	}

	return accessToken, itemID, nil
}

// GetAccounts retrieves account information for a user
func (pc *PlaidClient) GetAccounts(ctx context.Context, accessToken string) ([]PlaidAccount, error) {
	// Decrypt access token if it was encrypted
	decryptedToken, err := pc.decryptToken(accessToken)
	if err != nil {
		// If decryption fails, assume token is not encrypted
		decryptedToken = accessToken
	}

	request := plaid.NewAccountsGetRequest(decryptedToken)
	
	response, _, err := pc.client.PlaidApi.AccountsGet(ctx).AccountsGetRequest(*request).Execute()
	if err != nil {
		return nil, fmt.Errorf("failed to get accounts: %w", err)
	}

	var accounts []PlaidAccount
	for _, account := range response.GetAccounts() {
		plaidAccount := PlaidAccount{
			AccountID: account.GetAccountId(),
			Name:      account.GetName(),
			Type:      string(account.GetType()),
			Subtype:   string(account.GetSubtype()),
			AccessToken: accessToken,
		}

		// Get balance information
		if balances := account.GetBalances(); balances.Current.IsSet() {
			if current := balances.GetCurrent(); current != 0 {
				plaidAccount.Balance = current
			}
			if available := balances.GetAvailable(); available != 0 {
				plaidAccount.AvailableBalance = available
			}
		}

		accounts = append(accounts, plaidAccount)
	}

	return accounts, nil
}

// GetAuthData retrieves account and routing numbers for verified accounts
func (pc *PlaidClient) GetAuthData(ctx context.Context, accessToken string) ([]PlaidAccount, error) {
	// Decrypt access token if it was encrypted
	decryptedToken, err := pc.decryptToken(accessToken)
	if err != nil {
		decryptedToken = accessToken
	}

	request := plaid.NewAuthGetRequest(decryptedToken)
	
	response, _, err := pc.client.PlaidApi.AuthGet(ctx).AuthGetRequest(*request).Execute()
	if err != nil {
		return nil, fmt.Errorf("failed to get auth data: %w", err)
	}

	var accounts []PlaidAccount
	for _, account := range response.GetAccounts() {
		plaidAccount := PlaidAccount{
			AccountID: account.GetAccountId(),
			Name:      account.GetName(),
			Type:      string(account.GetType()),
			Subtype:   string(account.GetSubtype()),
			IsVerified: true, // Auth endpoint only returns verified accounts
			AccessToken: accessToken,
			Numbers:   &account, // Store the account base for reference
			Mask:      account.GetMask(),
		}

		// Get balance information
		if balances := account.GetBalances(); balances.Current.IsSet() {
			if current := balances.GetCurrent(); current != 0 {
				plaidAccount.Balance = current
			}
			if available := balances.GetAvailable(); available != 0 {
				plaidAccount.AvailableBalance = available
			}
		}

		accounts = append(accounts, plaidAccount)
	}

	// Get account numbers for verified accounts
	numbers := response.GetNumbers()
	achNumbers := numbers.GetAch()
	for i, achAccount := range achNumbers {
		if i < len(accounts) {
			accounts[i].AccountNumber = achAccount.GetAccount()
			accounts[i].RoutingNumber = achAccount.GetRouting()
		}
	}

	return accounts, nil
}

// GetTransactions retrieves transaction history for an account
func (pc *PlaidClient) GetTransactions(ctx context.Context, accessToken string, startDate, endDate time.Time) ([]PlaidTransaction, error) {
	// Decrypt access token if it was encrypted
	decryptedToken, err := pc.decryptToken(accessToken)
	if err != nil {
		decryptedToken = accessToken
	}

	request := plaid.NewTransactionsGetRequest(
		decryptedToken,
		startDate.Format("2006-01-02"),
		endDate.Format("2006-01-02"),
	)

	response, _, err := pc.client.PlaidApi.TransactionsGet(ctx).TransactionsGetRequest(*request).Execute()
	if err != nil {
		return nil, fmt.Errorf("failed to get transactions: %w", err)
	}

	var transactions []PlaidTransaction
	for _, txn := range response.GetTransactions() {
		// Parse the date string to time.Time
		dateStr := txn.GetDate()
		parsedDate, err := time.Parse("2006-01-02", dateStr)
		if err != nil {
			log.Printf("Error parsing transaction date %s: %v", dateStr, err)
			parsedDate = time.Now() // fallback to current time
		}

		transaction := PlaidTransaction{
			TransactionID: txn.GetTransactionId(),
			AccountID:     txn.GetAccountId(),
			Amount:        txn.GetAmount(),
			Date:          parsedDate,
			Name:          txn.GetName(),
			Category:      txn.GetCategory(),
			Pending:       txn.GetPending(),
		}
		transactions = append(transactions, transaction)
	}

	return transactions, nil
}

// GetBalance retrieves current balance for an account
func (pc *PlaidClient) GetBalance(ctx context.Context, accessToken string) ([]PlaidAccount, error) {
	// Decrypt access token if it was encrypted
	decryptedToken, err := pc.decryptToken(accessToken)
	if err != nil {
		decryptedToken = accessToken
	}

	request := plaid.NewAccountsBalanceGetRequest(decryptedToken)
	
	response, _, err := pc.client.PlaidApi.AccountsBalanceGet(ctx).AccountsBalanceGetRequest(*request).Execute()
	if err != nil {
		return nil, fmt.Errorf("failed to get balance: %w", err)
	}

	var accounts []PlaidAccount
	for _, account := range response.GetAccounts() {
		plaidAccount := PlaidAccount{
			AccountID: account.GetAccountId(),
			Name:      account.GetName(),
			Type:      string(account.GetType()),
			Subtype:   string(account.GetSubtype()),
			AccessToken: accessToken,
		}

		// Get balance information
		if balances := account.GetBalances(); balances.Current.IsSet() {
			if current := balances.GetCurrent(); current != 0 {
				plaidAccount.Balance = current
			}
			if available := balances.GetAvailable(); available != 0 {
				plaidAccount.AvailableBalance = available
			}
		}

		accounts = append(accounts, plaidAccount)
	}

	return accounts, nil
}

// TestConnection tests the Plaid API connection
func (pc *PlaidClient) TestConnection(ctx context.Context) error {
	// Create a test link token to verify API connectivity
	testUser := plaid.LinkTokenCreateRequestUser{
		ClientUserId: "test_user_" + fmt.Sprintf("%d", time.Now().Unix()),
	}

	request := plaid.NewLinkTokenCreateRequest(
		"Digital Payments Test",
		"en",
		pc.countryCodes,
		testUser,
	)
	request.SetProducts(pc.products)

	_, _, err := pc.client.PlaidApi.LinkTokenCreate(ctx).LinkTokenCreateRequest(*request).Execute()
	if err != nil {
		return fmt.Errorf("plaid connection test failed: %w", err)
	}

	log.Println("✅ Plaid connection test successful")
	return nil
}

// encryptToken encrypts an access token for secure storage
func (pc *PlaidClient) encryptToken(token string) (string, error) {
	key := []byte(pc.secret)
	if len(key) > 32 {
		key = key[:32] // AES-256 requires 32-byte key
	} else if len(key) < 32 {
		// Pad key to 32 bytes
		padded := make([]byte, 32)
		copy(padded, key)
		key = padded
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err = io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	ciphertext := gcm.Seal(nonce, nonce, []byte(token), nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// decryptToken decrypts an encrypted access token
func (pc *PlaidClient) decryptToken(encryptedToken string) (string, error) {
	key := []byte(pc.secret)
	if len(key) > 32 {
		key = key[:32]
	} else if len(key) < 32 {
		padded := make([]byte, 32)
		copy(padded, key)
		key = padded
	}

	data, err := base64.StdEncoding.DecodeString(encryptedToken)
	if err != nil {
		return "", err
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonceSize := gcm.NonceSize()
	if len(data) < nonceSize {
		return "", fmt.Errorf("ciphertext too short")
	}

	nonce, ciphertext := data[:nonceSize], data[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}

	return string(plaintext), nil
}

// ValidateUserConsent ensures user has provided consent for operations
func (pc *PlaidClient) ValidateUserConsent(ctx context.Context, userID string, operation string) error {
	// This would typically check a database for user consent records
	// For now, we'll implement a basic validation
	log.Printf("🔐 Validating user consent for user %s, operation: %s", userID, operation)
	
	// In a real implementation, you would:
	// 1. Check database for user consent records
	// 2. Verify consent is still valid (not expired)
	// 3. Ensure consent covers the specific operation
	
	return nil // Assume consent is valid for demo purposes
}

// LogAPIInteraction logs Plaid API interactions for audit trail
func (pc *PlaidClient) LogAPIInteraction(ctx context.Context, endpoint string, userID string, success bool, details string) {
	timestamp := time.Now().UTC()
	logEntry := fmt.Sprintf("[%s] Plaid API: %s | User: %s | Success: %t | Details: %s", 
		timestamp.Format(time.RFC3339), endpoint, userID, success, details)
	
	log.Println("📋 " + logEntry)
	
	// In a production environment, you would:
	// 1. Store this in a secure audit log database
	// 2. Include request/response IDs for traceability
	// 3. Implement log rotation and retention policies
	// 4. Add alerting for failed operations
}