package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

type SilaClient struct {
	baseURL      string
	appHandle    string
	clientID     string
	clientSecret string
	privateKey   string
	httpClient   *http.Client
}

// SilaAccount represents a Sila user account
type SilaAccount struct {
	UserHandle string `json:"user_handle"`
	FirstName  string `json:"first_name"`
	LastName   string `json:"last_name"`
	Email      string `json:"email"`
	Phone      string `json:"phone,omitempty"`
	Address    *SilaAddress `json:"address,omitempty"`
	Identity   *SilaIdentity `json:"identity,omitempty"`
	Status     string `json:"status"`
}

// SilaAddress represents a user's address
type SilaAddress struct {
	AddressAlias string `json:"address_alias"`
	StreetAddress1 string `json:"street_address_1"`
	StreetAddress2 string `json:"street_address_2,omitempty"`
	City         string `json:"city"`
	State        string `json:"state"`
	PostalCode   string `json:"postal_code"`
	Country      string `json:"country"`
}

// SilaIdentity represents user identity information
type SilaIdentity struct {
	IdentityAlias string `json:"identity_alias"`
	IdentityValue string `json:"identity_value"`
	IdentityType  string `json:"identity_type"` // "SSN", "EIN", etc.
}

// SilaTransfer represents a transfer request
type SilaTransfer struct {
	UserHandle     string  `json:"user_handle"`
	Amount         float64 `json:"amount"`
	AccountName    string  `json:"account_name"`
	Descriptor     string  `json:"descriptor,omitempty"`
	BusinessUUID   string  `json:"business_uuid,omitempty"`
	ProcessingType string  `json:"processing_type,omitempty"` // "STANDARD_ACH", "SAME_DAY_ACH"
}

// SilaWallet represents a digital wallet
type SilaWallet struct {
	UserHandle    string  `json:"user_handle"`
	WalletID      string  `json:"wallet_id"`
	Balance       float64 `json:"balance"`
	Currency      string  `json:"currency"`
	Status        string  `json:"status"`
}

// NewSilaClient initializes a new Sila client with credentials from environment
func NewSilaClient() (*SilaClient, error) {
	appHandle := os.Getenv("SILA_APP_HANDLE")
	clientID := os.Getenv("SILA_CLIENT_ID")
	clientSecret := os.Getenv("SILA_CLIENT_SECRET")
	privateKey := os.Getenv("SILA_PRIVATE_KEY")
	baseURL := os.Getenv("SILA_BASE_URL")

	if appHandle == "" {
		return nil, fmt.Errorf("missing required SILA_APP_HANDLE environment variable")
	}

	if clientID == "" {
		return nil, fmt.Errorf("missing required SILA_CLIENT_ID environment variable")
	}

	if clientSecret == "" {
		return nil, fmt.Errorf("missing required SILA_CLIENT_SECRET environment variable")
	}

	if privateKey == "" {
		return nil, fmt.Errorf("missing required SILA_PRIVATE_KEY environment variable")
	}

	if baseURL == "" {
		baseURL = "https://sandbox.silamoney.com" // Default to sandbox
	}

	return &SilaClient{
		baseURL:      baseURL,
		appHandle:    appHandle,
		clientID:     clientID,
		clientSecret: clientSecret,
		privateKey:   privateKey,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}, nil
}

// makeRequest makes an authenticated request to the Sila API
func (sc *SilaClient) makeRequest(ctx context.Context, method, endpoint string, payload interface{}) (*http.Response, error) {
	var body io.Reader
	if payload != nil {
		jsonData, err := json.Marshal(payload)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal request payload: %w", err)
		}
		body = bytes.NewBuffer(jsonData)
	}

	req, err := http.NewRequestWithContext(ctx, method, sc.baseURL+endpoint, body)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Add required headers
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("authsignature", sc.generateAuthSignature(payload))
	req.Header.Set("usersignature", sc.generateUserSignature(payload))

	return sc.httpClient.Do(req)
}

// generateAuthSignature generates the authentication signature for Sila API
func (sc *SilaClient) generateAuthSignature(payload interface{}) string {
	// TODO: Implement proper ECDSA signature generation
	// This is a placeholder - in production, you would use the private key
	// to generate a proper ECDSA signature of the request payload
	return "placeholder_auth_signature"
}

// generateUserSignature generates the user signature for Sila API
func (sc *SilaClient) generateUserSignature(payload interface{}) string {
	// TODO: Implement proper user signature generation
	// This would typically be generated using the user's private key
	return "placeholder_user_signature"
}

// RegisterUser registers a new user with Sila
func (sc *SilaClient) RegisterUser(ctx context.Context, account *SilaAccount) (*SilaAccount, error) {
	payload := map[string]interface{}{
		"header": map[string]interface{}{
			"created":     time.Now().Unix(),
			"app_handle":  sc.appHandle,
			"user_handle": account.UserHandle,
		},
		"first_name": account.FirstName,
		"last_name":  account.LastName,
		"entity_name": account.FirstName + " " + account.LastName,
		"address": account.Address,
		"identity": account.Identity,
		"contact": map[string]interface{}{
			"phone": account.Phone,
			"email": account.Email,
		},
		"crypto_entry": map[string]interface{}{
			"crypto_address": "placeholder_crypto_address",
			"crypto_code":    "ETH",
		},
	}

	resp, err := sc.makeRequest(ctx, "POST", "/0.2/register", payload)
	if err != nil {
		return nil, fmt.Errorf("failed to register user: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("registration failed with status: %d", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	account.Status = "registered"
	return account, nil
}

// GetUser retrieves user information from Sila
func (sc *SilaClient) GetUser(ctx context.Context, userHandle string) (*SilaAccount, error) {
	payload := map[string]interface{}{
		"header": map[string]interface{}{
			"created":     time.Now().Unix(),
			"app_handle":  sc.appHandle,
			"user_handle": userHandle,
		},
	}

	resp, err := sc.makeRequest(ctx, "POST", "/0.2/get_entity", payload)
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("get user failed with status: %d", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// Parse the response and return SilaAccount
	account := &SilaAccount{
		UserHandle: userHandle,
		Status:     "active",
	}

	return account, nil
}

// LinkBankAccount links a bank account to a user
func (sc *SilaClient) LinkBankAccount(ctx context.Context, userHandle, accountNumber, routingNumber, accountName string) error {
	payload := map[string]interface{}{
		"header": map[string]interface{}{
			"created":     time.Now().Unix(),
			"app_handle":  sc.appHandle,
			"user_handle": userHandle,
		},
		"account_number":  accountNumber,
		"routing_number":  routingNumber,
		"account_name":    accountName,
		"account_type":    "CHECKING",
	}

	resp, err := sc.makeRequest(ctx, "POST", "/0.2/link_account", payload)
	if err != nil {
		return fmt.Errorf("failed to link bank account: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("link bank account failed with status: %d", resp.StatusCode)
	}

	return nil
}

// IssueTransfer initiates a transfer (deposit) from bank account to Sila wallet
func (sc *SilaClient) IssueTransfer(ctx context.Context, transfer *SilaTransfer) (string, error) {
	payload := map[string]interface{}{
		"header": map[string]interface{}{
			"created":     time.Now().Unix(),
			"app_handle":  sc.appHandle,
			"user_handle": transfer.UserHandle,
		},
		"amount":         transfer.Amount,
		"account_name":   transfer.AccountName,
		"descriptor":     transfer.Descriptor,
		"business_uuid":  transfer.BusinessUUID,
		"processing_type": transfer.ProcessingType,
	}

	resp, err := sc.makeRequest(ctx, "POST", "/0.2/issue_sila", payload)
	if err != nil {
		return "", fmt.Errorf("failed to issue transfer: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("issue transfer failed with status: %d", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", fmt.Errorf("failed to decode response: %w", err)
	}

	// Extract transaction ID from response
	if transactionID, ok := result["transaction_id"].(string); ok {
		return transactionID, nil
	}

	return "", fmt.Errorf("transaction ID not found in response")
}

// RedeemTransfer initiates a transfer (withdrawal) from Sila wallet to bank account
func (sc *SilaClient) RedeemTransfer(ctx context.Context, transfer *SilaTransfer) (string, error) {
	payload := map[string]interface{}{
		"header": map[string]interface{}{
			"created":     time.Now().Unix(),
			"app_handle":  sc.appHandle,
			"user_handle": transfer.UserHandle,
		},
		"amount":         transfer.Amount,
		"account_name":   transfer.AccountName,
		"descriptor":     transfer.Descriptor,
		"processing_type": transfer.ProcessingType,
	}

	resp, err := sc.makeRequest(ctx, "POST", "/0.2/redeem_sila", payload)
	if err != nil {
		return "", fmt.Errorf("failed to redeem transfer: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("redeem transfer failed with status: %d", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", fmt.Errorf("failed to decode response: %w", err)
	}

	// Extract transaction ID from response
	if transactionID, ok := result["transaction_id"].(string); ok {
		return transactionID, nil
	}

	return "", fmt.Errorf("transaction ID not found in response")
}

// TransferSila transfers Sila between users (P2P transfer)
func (sc *SilaClient) TransferSila(ctx context.Context, fromUserHandle, toUserHandle string, amount float64, descriptor string) (string, error) {
	payload := map[string]interface{}{
		"header": map[string]interface{}{
			"created":     time.Now().Unix(),
			"app_handle":  sc.appHandle,
			"user_handle": fromUserHandle,
		},
		"destination_handle": toUserHandle,
		"amount":            amount,
		"descriptor":        descriptor,
	}

	resp, err := sc.makeRequest(ctx, "POST", "/0.2/transfer_sila", payload)
	if err != nil {
		return "", fmt.Errorf("failed to transfer sila: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("transfer sila failed with status: %d", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", fmt.Errorf("failed to decode response: %w", err)
	}

	// Extract transaction ID from response
	if transactionID, ok := result["transaction_id"].(string); ok {
		return transactionID, nil
	}

	return "", fmt.Errorf("transaction ID not found in response")
}

// GetBalance retrieves the Sila wallet balance for a user
func (sc *SilaClient) GetBalance(ctx context.Context, userHandle string) (*SilaWallet, error) {
	payload := map[string]interface{}{
		"header": map[string]interface{}{
			"created":     time.Now().Unix(),
			"app_handle":  sc.appHandle,
			"user_handle": userHandle,
		},
	}

	resp, err := sc.makeRequest(ctx, "POST", "/0.2/get_sila_balance", payload)
	if err != nil {
		return nil, fmt.Errorf("failed to get balance: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("get balance failed with status: %d", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	wallet := &SilaWallet{
		UserHandle: userHandle,
		Currency:   "USD",
		Status:     "active",
	}

	// Extract balance from response
	if balance, ok := result["sila_balance"].(float64); ok {
		wallet.Balance = balance
	}

	return wallet, nil
}

// TestConnection tests the connection to Sila API
func (sc *SilaClient) TestConnection(ctx context.Context) error {
	payload := map[string]interface{}{
		"header": map[string]interface{}{
			"created":    time.Now().Unix(),
			"app_handle": sc.appHandle,
		},
	}

	resp, err := sc.makeRequest(ctx, "POST", "/0.2/check_handle", payload)
	if err != nil {
		return fmt.Errorf("failed to connect to Sila API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("Sila API connection test failed with status: %d", resp.StatusCode)
	}

	return nil
}