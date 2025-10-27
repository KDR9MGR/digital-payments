package main

import (
	"fmt"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
)

// CreateStripeCustomerRequest represents the request to create a Stripe customer
type CreateStripeCustomerRequest struct {
	Email  string `json:"email" binding:"required"`
	Name   string `json:"name" binding:"required"`
	UserID string `json:"user_id" binding:"required"`
}

// CreatePaymentMethodRequest represents the request to create a payment method from Plaid
type CreatePaymentMethodRequest struct {
	PlaidAccountID string `json:"plaid_account_id" binding:"required"`
	CustomerID     string `json:"customer_id" binding:"required"`
	AccessToken    string `json:"access_token" binding:"required"`
}

// CreateTransferRequest represents the request to create a transfer
type CreateTransferRequest struct {
	Amount              int64  `json:"amount" binding:"required"`
	Currency            string `json:"currency" binding:"required"`
	SourceAccountID     string `json:"source_account_id" binding:"required"`
	DestinationAccountID string `json:"destination_account_id" binding:"required"`
	Description         string `json:"description"`
	UserID              string `json:"user_id" binding:"required"`
}

// ConfirmTransferRequest represents the request to confirm a transfer
type ConfirmTransferRequest struct {
	PaymentIntentID string `json:"payment_intent_id" binding:"required"`
	UserConsent     bool   `json:"user_consent" binding:"required"`
}

// CreateStripeCustomer creates a new Stripe customer
func CreateStripeCustomer(c *gin.Context) {
	var req CreateStripeCustomerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get Stripe client from context
	stripeClient, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Stripe client not available"})
		return
	}

	sc := stripeClient.(*StripeClient)

	// Create customer
	customer, err := sc.CreateCustomer(c.Request.Context(), req.Email, req.Name, req.UserID)
	if err != nil {
		sc.LogAPIInteraction(c.Request.Context(), "create_customer", req.UserID, false, err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create customer"})
		return
	}

	sc.LogAPIInteraction(c.Request.Context(), "create_customer", req.UserID, true, fmt.Sprintf("Customer ID: %s", customer.ID))

	c.JSON(http.StatusOK, gin.H{
		"customer": customer,
		"message":  "Customer created successfully",
	})
}

// CreatePaymentMethodFromPlaid creates a Stripe payment method using Plaid account verification
func CreatePaymentMethodFromPlaid(c *gin.Context) {
	var req CreatePaymentMethodRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get clients from context
	plaidClient, exists := c.Get("plaidClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Plaid client not available"})
		return
	}

	stripeClient, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Stripe client not available"})
		return
	}

	pc := plaidClient.(*PlaidClient)
	sc := stripeClient.(*StripeClient)

	// Get account details from Plaid
	accounts, err := pc.GetAccounts(c.Request.Context(), req.AccessToken)
	if err != nil {
		sc.LogAPIInteraction(c.Request.Context(), "get_plaid_accounts", "", false, err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get account details from Plaid"})
		return
	}

	// Find the specific account
	var targetAccount *PlaidAccount
	for _, account := range accounts {
		if account.AccountID == req.PlaidAccountID {
			targetAccount = &account
			break
		}
	}

	if targetAccount == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Account not found"})
		return
	}

	// Get auth data for routing and account numbers
	authData, err := pc.GetAuthData(c.Request.Context(), req.AccessToken)
	if err != nil {
		sc.LogAPIInteraction(c.Request.Context(), "get_plaid_auth", "", false, err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get account auth data"})
		return
	}

	// Find auth data for the specific account
	var routingNumber, accountNumber string
	for _, authAccount := range authData {
		if authAccount.AccountID == req.PlaidAccountID {
			// Use the routing and account numbers that were already extracted
			routingNumber = authAccount.RoutingNumber
			accountNumber = authAccount.AccountNumber
			break
		}
	}

	if routingNumber == "" || accountNumber == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Unable to retrieve account numbers"})
		return
	}

	// Determine account type
	accountType := "checking"
	if targetAccount.Type == "depository" && targetAccount.Subtype == "savings" {
		accountType = "savings"
	}

	// Create Stripe payment method
	paymentMethod, err := sc.CreatePaymentMethodFromPlaid(
		c.Request.Context(),
		req.PlaidAccountID,
		routingNumber,
		accountNumber,
		accountType,
	)
	if err != nil {
		sc.LogAPIInteraction(c.Request.Context(), "create_payment_method", "", false, err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create payment method"})
		return
	}

	sc.LogAPIInteraction(c.Request.Context(), "create_payment_method", "", true, fmt.Sprintf("Payment Method ID: %s", paymentMethod.ID))

	c.JSON(http.StatusOK, gin.H{
		"payment_method": paymentMethod,
		"account_info": gin.H{
			"account_id":   targetAccount.AccountID,
			"account_name": targetAccount.Name,
			"account_type": accountType,
			"mask":         targetAccount.Mask,
		},
		"message": "Payment method created successfully",
	})
}

// CreateTransferWithStripe creates a transfer using Stripe with Plaid verification
func CreateTransferWithStripe(c *gin.Context) {
	var req CreateTransferRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get Stripe client from context
	stripeClient, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Stripe client not available"})
		return
	}

	sc := stripeClient.(*StripeClient)

	// Validate minimum transfer amount (e.g., $1.00)
	if req.Amount < 100 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Minimum transfer amount is $1.00"})
		return
	}

	// Set default currency if not provided
	if req.Currency == "" {
		req.Currency = "usd"
	}

	// TODO: In a real implementation, you would:
	// 1. Validate user owns both accounts
	// 2. Check account balances
	// 3. Verify account status and eligibility
	// 4. Get customer ID and payment method ID from database

	// For now, we'll create a payment intent that requires confirmation
	paymentIntent, err := sc.CreatePaymentIntent(
		c.Request.Context(),
		req.Amount,
		req.Currency,
		"", // Customer ID would come from database
		"", // Payment method ID would come from database
	)
	if err != nil {
		sc.LogAPIInteraction(c.Request.Context(), "create_transfer", req.UserID, false, err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create transfer"})
		return
	}

	sc.LogAPIInteraction(c.Request.Context(), "create_transfer", req.UserID, true, fmt.Sprintf("Payment Intent ID: %s", paymentIntent.ID))

	c.JSON(http.StatusOK, gin.H{
		"transfer_id":       paymentIntent.ID,
		"amount":           req.Amount,
		"currency":         req.Currency,
		"status":           paymentIntent.Status,
		"client_secret":    paymentIntent.ClientSecret,
		"requires_confirmation": true,
		"message":          "Transfer initiated, requires confirmation",
	})
}

// CreateP2PTransferWithStripe creates a peer-to-peer transfer using Stripe
func CreateP2PTransferWithStripe(c *gin.Context) {
	var req CreateTransferRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get Stripe client from context
	stripeClient, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Stripe client not available"})
		return
	}

	sc := stripeClient.(*StripeClient)

	// Validate minimum transfer amount
	if req.Amount < 100 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Minimum transfer amount is $1.00"})
		return
	}

	// Set default currency if not provided
	if req.Currency == "" {
		req.Currency = "usd"
	}

	// TODO: In a real implementation, you would:
	// 1. Validate sender and recipient accounts
	// 2. Check sender's account balance
	// 3. Verify both users exist and accounts are verified
	// 4. Apply any transfer limits or fees

	// Create payment intent for P2P transfer
	paymentIntent, err := sc.CreatePaymentIntent(
		c.Request.Context(),
		req.Amount,
		req.Currency,
		"", // Sender's customer ID
		"", // Sender's payment method ID
	)
	if err != nil {
		sc.LogAPIInteraction(c.Request.Context(), "create_p2p_transfer", req.UserID, false, err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create P2P transfer"})
		return
	}

	sc.LogAPIInteraction(c.Request.Context(), "create_p2p_transfer", req.UserID, true, fmt.Sprintf("P2P Transfer ID: %s", paymentIntent.ID))

	c.JSON(http.StatusOK, gin.H{
		"transfer_id":       paymentIntent.ID,
		"amount":           req.Amount,
		"currency":         req.Currency,
		"status":           paymentIntent.Status,
		"client_secret":    paymentIntent.ClientSecret,
		"type":             "p2p",
		"requires_confirmation": true,
		"message":          "P2P transfer initiated, requires confirmation",
	})
}

// ConfirmTransfer confirms a pending transfer
func ConfirmTransfer(c *gin.Context) {
	var req ConfirmTransferRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if !req.UserConsent {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User consent is required"})
		return
	}

	// Get Stripe client from context
	stripeClient, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Stripe client not available"})
		return
	}

	sc := stripeClient.(*StripeClient)

	// Confirm the payment intent
	paymentIntent, err := sc.ConfirmPaymentIntent(c.Request.Context(), req.PaymentIntentID)
	if err != nil {
		sc.LogAPIInteraction(c.Request.Context(), "confirm_transfer", "", false, err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to confirm transfer"})
		return
	}

	sc.LogAPIInteraction(c.Request.Context(), "confirm_transfer", "", true, fmt.Sprintf("Confirmed Payment Intent: %s", paymentIntent.ID))

	c.JSON(http.StatusOK, gin.H{
		"transfer_id": paymentIntent.ID,
		"status":      paymentIntent.Status,
		"amount":      paymentIntent.Amount,
		"currency":    paymentIntent.Currency,
		"message":     "Transfer confirmed successfully",
	})
}

// GetTransferStatus gets the status of a transfer
func GetTransferStatus(c *gin.Context) {
	transferID := c.Param("id")
	if transferID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Transfer ID is required"})
		return
	}

	// Get Stripe client from context
	stripeClient, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Stripe client not available"})
		return
	}

	sc := stripeClient.(*StripeClient)

	// Get payment intent status
	paymentIntent, err := sc.GetPaymentIntent(c.Request.Context(), transferID)
	if err != nil {
		sc.LogAPIInteraction(c.Request.Context(), "get_transfer_status", "", false, err.Error())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get transfer status"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"transfer_id": paymentIntent.ID,
		"status":      paymentIntent.Status,
		"amount":      paymentIntent.Amount,
		"currency":    paymentIntent.Currency,
	})
}

// HandleStripeWebhook handles Stripe webhook events
func HandleStripeWebhook(c *gin.Context) {
	// Get Stripe client from context
	stripeClient, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Stripe client not available"})
		return
	}

	sc := stripeClient.(*StripeClient)

	// Read the request body
	payload, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to read request body"})
		return
	}

	// Get the signature header
	signature := c.GetHeader("Stripe-Signature")
	if signature == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing Stripe signature"})
		return
	}

	// Validate the webhook
	event, err := sc.ValidateWebhook(payload, signature)
	if err != nil {
		sc.LogAPIInteraction(c.Request.Context(), "webhook_validation", "", false, err.Error())
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid webhook signature"})
		return
	}

	// Handle different event types
	switch event.Type {
	case "payment_intent.succeeded":
		// Handle successful payment
		sc.LogAPIInteraction(c.Request.Context(), "webhook_payment_succeeded", "", true, fmt.Sprintf("Event ID: %s", event.ID))
		
	case "payment_intent.payment_failed":
		// Handle failed payment
		sc.LogAPIInteraction(c.Request.Context(), "webhook_payment_failed", "", true, fmt.Sprintf("Event ID: %s", event.ID))
		
	case "setup_intent.succeeded":
		// Handle successful setup intent (payment method saved)
		sc.LogAPIInteraction(c.Request.Context(), "webhook_setup_succeeded", "", true, fmt.Sprintf("Event ID: %s", event.ID))
		
	default:
		// Log unhandled event types
		sc.LogAPIInteraction(c.Request.Context(), "webhook_unhandled", "", true, fmt.Sprintf("Event Type: %s, ID: %s", event.Type, event.ID))
	}

	c.JSON(http.StatusOK, gin.H{"received": true})
}