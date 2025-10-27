package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

// User represents a user in our system
type User struct {
	ID                   string    `json:"id"`
	Email                string    `json:"email"`
	PasswordHash         string    `json:"-"` // Don't include in JSON responses
	FirstName            string    `json:"first_name"`
	LastName             string    `json:"last_name"`
	StripeConnectID      string    `json:"stripe_connect_id,omitempty"`
	StripeCustomerID     string    `json:"stripe_customer_id,omitempty"`
	StripeAccountStatus  string    `json:"stripe_account_status,omitempty"`
	CreatedAt            time.Time `json:"created_at"`
}

// Simple in-memory user store (in production, use a proper database)
var (
	userStore = make(map[string]*User)
	userMutex = sync.RWMutex{}
)

// Initialize with a test user
func init() {
	// Create a test user with email: test@example.com, password: password123
	hashedPassword, _ := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.DefaultCost)
	testUser := &User{
		ID:           "test-user-id",
		Email:        "test@example.com",
		PasswordHash: string(hashedPassword),
		FirstName:    "Test",
		LastName:     "User",
		CreatedAt:    time.Now(),
	}
	userStore[testUser.Email] = testUser
}

// Helper functions for user management
func getUserByEmail(email string) (*User, bool) {
	userMutex.RLock()
	defer userMutex.RUnlock()
	user, exists := userStore[email]
	return user, exists
}

func createUser(email, password, firstName, lastName string) (*User, error) {
	userMutex.Lock()
	defer userMutex.Unlock()
	
	// Check if user already exists
	if _, exists := userStore[email]; exists {
		return nil, fmt.Errorf("user already exists")
	}
	
	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}
	
	user := &User{
		ID:           uuid.New().String(),
		Email:        email,
		PasswordHash: string(hashedPassword),
		FirstName:    firstName,
		LastName:     lastName,
		CreatedAt:    time.Now(),
	}
	
	userStore[email] = user
	return user, nil
}

func validatePassword(hashedPassword, password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password))
	return err == nil
}

// HealthCheck returns the health status of the API
func HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"timestamp": time.Now().UTC(),
		"service":   "digital-payments-backend",
	})
}

// ReceiveMoney handles incoming transfer notifications and updates
func ReceiveMoney(c *gin.Context) {
	// Request structure for receiving money notifications
	var request struct {
		TransferID    string  `json:"transfer_id" binding:"required"`
		Amount        float64 `json:"amount" binding:"required,min=0.01"`
		Currency      string  `json:"currency" binding:"required"`
		SenderEmail   string  `json:"sender_email" binding:"required,email"`
		Description   string  `json:"description"`
		Status        string  `json:"status" binding:"required"`
	}

	// Validate request body
	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request format",
			"details": err.Error(),
		})
		return
	}

	// Get receiver from JWT token
	receiverEmail, exists := c.Get("email")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
			"details": "Please log in to receive money",
		})
		return
	}

	// Validate currency
	if strings.ToUpper(request.Currency) != "USD" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Unsupported currency",
			"details": "Only USD is currently supported",
		})
		return
	}

	// Validate status
	validStatuses := map[string]bool{
		"pending":   true,
		"completed": true,
		"failed":    true,
		"cancelled": true,
	}
	if !validStatuses[strings.ToLower(request.Status)] {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid status",
			"details": "Status must be one of: pending, completed, failed, cancelled",
		})
		return
	}

	// Get receiver user
	userMutex.RLock()
	receiver, exists := userStore[receiverEmail.(string)]
	userMutex.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Receiver not found",
			"details": "Your account could not be found",
		})
		return
	}

	if receiver.StripeConnectID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Receiver does not have a Stripe Connect account",
			"details": "You need to complete your payment account setup to receive money",
		})
		return
	}

	// Validate sender exists (optional check for security)
	userMutex.RLock()
	sender, senderExists := userStore[request.SenderEmail]
	userMutex.RUnlock()

	if !senderExists {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid sender",
			"details": "The sender is not registered in our system",
		})
		return
	}

	// Log the incoming transfer for audit purposes
	log.Printf("Incoming transfer notification: ID=%s, Amount=%.2f %s, From=%s (ID: %s), To=%s, Status=%s", 
		request.TransferID, request.Amount, request.Currency, request.SenderEmail, sender.ID, receiverEmail.(string), request.Status)

	// Prepare response based on status
	responseData := gin.H{
		"transfer_id":    request.TransferID,
		"amount":         request.Amount,
		"currency":       request.Currency,
		"sender_email":   request.SenderEmail,
		"receiver_email": receiverEmail.(string),
		"description":    request.Description,
		"status":         request.Status,
		"processed_at":   time.Now().UTC(),
	}

	switch strings.ToLower(request.Status) {
	case "completed":
		responseData["message"] = "Money received successfully"
		c.JSON(http.StatusOK, responseData)
	case "pending":
		responseData["message"] = "Transfer is being processed"
		c.JSON(http.StatusAccepted, responseData)
	case "failed":
		responseData["message"] = "Transfer failed"
		responseData["error"] = "The transfer could not be completed"
		c.JSON(http.StatusBadRequest, responseData)
	case "cancelled":
		responseData["message"] = "Transfer was cancelled"
		c.JSON(http.StatusOK, responseData)
	default:
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Unknown status",
			"details": "The transfer status is not recognized",
		})
	}
}

// Login handles user authentication with hybrid Firebase and Stripe Connect verification
func Login(c *gin.Context) {
	var loginRequest struct {
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password" binding:"required"`
	}

	if err := c.ShouldBindJSON(&loginRequest); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get user from store
	user, exists := getUserByEmail(loginRequest.Email)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
		return
	}

	// Validate password
	if !validatePassword(user.PasswordHash, loginRequest.Password) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
		return
	}

	// Get Stripe client from context for account verification
	stripeClientInterface, exists := c.Get("stripeClient")
	var stripeAccountInfo *StripeConnectAccount
	var accountStatus string = user.StripeAccountStatus

	if exists && user.StripeConnectID != "" {
		stripeClient := stripeClientInterface.(*StripeClient)
		ctx := context.Background()

		// Verify Stripe Connect account status
		connectAccount, err := stripeClient.GetConnectAccount(ctx, user.StripeConnectID)
		if err != nil {
			log.Printf("Failed to retrieve Stripe Connect account for user %s: %v", user.ID, err)
			// Continue with login but mark account status as error
			accountStatus = "verification_error"
		} else {
			stripeAccountInfo = connectAccount
			// Update account status based on Stripe account state
			if connectAccount.DetailsSubmitted && connectAccount.ChargesEnabled && connectAccount.PayoutsEnabled {
				accountStatus = "active"
			} else if connectAccount.DetailsSubmitted {
				accountStatus = "pending_approval"
			} else {
				accountStatus = "pending_verification"
			}

			// Update user's account status if it has changed
			if accountStatus != user.StripeAccountStatus {
				userMutex.Lock()
				user.StripeAccountStatus = accountStatus
				userStore[user.Email] = user
				userMutex.Unlock()
			}
		}

		// Log successful login
		stripeClient.LogAPIInteraction(ctx, "user_login", user.ID, true, 
			fmt.Sprintf("Login successful, account status: %s", accountStatus))
	}

	// Generate JWT token
	token, err := GenerateJWT(user.ID, user.Email, "")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	response := gin.H{
		"token":                token,
		"userID":               user.ID,
		"email":                user.Email,
		"firstName":            user.FirstName,
		"lastName":             user.LastName,
		"stripeCustomerID":     user.StripeCustomerID,
		"stripeConnectID":      user.StripeConnectID,
		"stripeAccountStatus":  accountStatus,
	}

	// Include detailed Stripe account info if available
	if stripeAccountInfo != nil {
		response["stripeAccountDetails"] = gin.H{
			"chargesEnabled":    stripeAccountInfo.ChargesEnabled,
			"payoutsEnabled":    stripeAccountInfo.PayoutsEnabled,
			"detailsSubmitted":  stripeAccountInfo.DetailsSubmitted,
			"requirements":      stripeAccountInfo.Requirements,
		}
	}

	c.JSON(http.StatusOK, response)
}

// Register handles user registration with hybrid Firebase and Stripe Connect authentication
func Register(c *gin.Context) {
	var registerRequest struct {
		Email       string `json:"email" binding:"required,email"`
		Password    string `json:"password" binding:"required,min=8"`
		FirstName   string `json:"first_name" binding:"required"`
		LastName    string `json:"last_name" binding:"required"`
		AccountType string `json:"account_type"` // "individual" or "company", defaults to "individual"
	}

	if err := c.ShouldBindJSON(&registerRequest); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Default to individual account type if not specified
	if registerRequest.AccountType == "" {
		registerRequest.AccountType = "individual"
	}

	// Validate account type
	if registerRequest.AccountType != "individual" && registerRequest.AccountType != "company" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Account type must be 'individual' or 'company'"})
		return
	}

	// Create new user
	user, err := createUser(registerRequest.Email, registerRequest.Password, registerRequest.FirstName, registerRequest.LastName)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "User already exists"})
		return
	}

	// Get Stripe client from context
	stripeClientInterface, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Stripe service unavailable"})
		return
	}
	stripeClient := stripeClientInterface.(*StripeClient)

	ctx := context.Background()

	// Create Stripe customer
	stripeCustomer, err := stripeClient.CreateCustomer(ctx, user.Email, user.FirstName+" "+user.LastName, user.ID)
	if err != nil {
		log.Printf("Failed to create Stripe customer for user %s: %v", user.ID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create payment account"})
		return
	}

	// Create Stripe Connect account
	stripeConnectAccount, err := stripeClient.CreateConnectAccount(ctx, user.Email, user.ID, registerRequest.AccountType)
	if err != nil {
		log.Printf("Failed to create Stripe Connect account for user %s: %v", user.ID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create merchant account"})
		return
	}

	// Update user with Stripe information
	userMutex.Lock()
	user.StripeCustomerID = stripeCustomer.ID
	user.StripeConnectID = stripeConnectAccount.ID
	user.StripeAccountStatus = "pending_verification"
	userStore[user.Email] = user
	userMutex.Unlock()

	// Generate JWT token
	token, err := GenerateJWT(user.ID, user.Email, "")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	// Log successful registration
	stripeClient.LogAPIInteraction(ctx, "user_registration", user.ID, true, 
		fmt.Sprintf("Created customer %s and connect account %s", stripeCustomer.ID, stripeConnectAccount.ID))

	c.JSON(http.StatusCreated, gin.H{
		"token":                 token,
		"userID":                user.ID,
		"email":                 user.Email,
		"firstName":             user.FirstName,
		"lastName":              user.LastName,
		"stripeCustomerID":      user.StripeCustomerID,
		"stripeConnectID":       user.StripeConnectID,
		"stripeAccountStatus":   user.StripeAccountStatus,
		"accountType":           registerRequest.AccountType,
	})
}

// CreateLinkToken creates a Plaid Link token for bank account connection
func CreateLinkToken(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		var request struct {
			UserID string `json:"user_id" binding:"required"`
		}

		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		if plaidClient == nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Plaid service unavailable"})
			return
		}

		// Validate user consent
		ctx := context.Background()
		if err := plaidClient.ValidateUserConsent(ctx, request.UserID, "link_account"); err != nil {
			plaidClient.LogAPIInteraction(ctx, "/link/token/create", request.UserID, false, "User consent validation failed")
			c.JSON(http.StatusForbidden, gin.H{"error": "User consent required"})
			return
		}

		linkToken, err := plaidClient.CreateLinkToken(ctx, request.UserID)
		if err != nil {
			plaidClient.LogAPIInteraction(ctx, "/link/token/create", request.UserID, false, err.Error())
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create link token"})
			return
		}

		plaidClient.LogAPIInteraction(ctx, "/link/token/create", request.UserID, true, "Link token created successfully")

		c.JSON(http.StatusOK, gin.H{
			"link_token": linkToken,
			"expiration": time.Now().Add(4 * time.Hour).Unix(), // Link tokens expire in 4 hours
		})
	}
}

// ExchangePublicToken exchanges a public token for an access token
func ExchangePublicToken(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		var request struct {
			PublicToken string `json:"public_token" binding:"required"`
			UserID      string `json:"user_id" binding:"required"`
		}

		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		if plaidClient == nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Plaid service unavailable"})
			return
		}

		ctx := context.Background()
		
		// Validate user consent
		if err := plaidClient.ValidateUserConsent(ctx, request.UserID, "exchange_token"); err != nil {
			plaidClient.LogAPIInteraction(ctx, "/item/public_token/exchange", request.UserID, false, "User consent validation failed")
			c.JSON(http.StatusForbidden, gin.H{"error": "User consent required"})
			return
		}

		accessToken, itemID, err := plaidClient.ExchangePublicToken(ctx, request.PublicToken)
		if err != nil {
			plaidClient.LogAPIInteraction(ctx, "/item/public_token/exchange", request.UserID, false, err.Error())
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to exchange public token"})
			return
		}

		// TODO: Store accessToken and itemID securely in your database associated with userID
		// For now, we'll return them (in production, never expose access tokens to frontend)

		plaidClient.LogAPIInteraction(ctx, "/item/public_token/exchange", request.UserID, true, "Public token exchanged successfully")

		c.JSON(http.StatusOK, gin.H{
			"success":      true,
			"item_id":      itemID,
			"access_token": accessToken, // Remove this in production
		})
	}
}

// CreateAccount creates a user account (placeholder for user management)
func CreateAccount(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		var request struct {
			UserID    string `json:"user_id" binding:"required"`
			FirstName string `json:"first_name" binding:"required"`
			LastName  string `json:"last_name" binding:"required"`
			Email     string `json:"email" binding:"required,email"`
		}

		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// TODO: Store user account in your database
		// This is a placeholder implementation

		user := PlaidUser{
			UserID:    request.UserID,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		}

		c.JSON(http.StatusCreated, gin.H{
			"user":    user,
			"message": "Account created successfully",
		})
	}
}

// GetAccount retrieves user account information
func GetAccount(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("userID")
		if userID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
			return
		}

		// TODO: Retrieve user account from your database
		// This is a placeholder implementation

		user := PlaidUser{
			UserID:    userID,
			CreatedAt: time.Now().Add(-24 * time.Hour),
			UpdatedAt: time.Now(),
		}

		c.JSON(http.StatusOK, gin.H{
			"user": user,
		})
	}
}

// UpdateAccount updates user account information
func UpdateAccount(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("userID")
		if userID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
			return
		}

		var request struct {
			FirstName string `json:"first_name"`
			LastName  string `json:"last_name"`
			Email     string `json:"email"`
		}

		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// TODO: Update user account in your database
		// This is a placeholder implementation

		c.JSON(http.StatusOK, gin.H{
			"message": "Account updated successfully",
		})
	}
}

// GetAuthData retrieves account and routing numbers for verified accounts
func GetAuthData(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("userID")
		if userID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
			return
		}

		if plaidClient == nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Plaid service unavailable"})
			return
		}

		// TODO: Retrieve access token from your database for this user
		accessToken := c.GetHeader("X-Access-Token") // Temporary - should come from database
		if accessToken == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Access token required"})
			return
		}

		ctx := context.Background()
		
		// Validate user consent for accessing auth data
		if err := plaidClient.ValidateUserConsent(ctx, userID, "get_auth_data"); err != nil {
			plaidClient.LogAPIInteraction(ctx, "/auth/get", userID, false, "User consent validation failed")
			c.JSON(http.StatusForbidden, gin.H{"error": "User consent required"})
			return
		}

		accounts, err := plaidClient.GetAuthData(ctx, accessToken)
		if err != nil {
			plaidClient.LogAPIInteraction(ctx, "/auth/get", userID, false, err.Error())
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get auth data"})
			return
		}

		plaidClient.LogAPIInteraction(ctx, "/auth/get", userID, true, "Auth data retrieved successfully")

		c.JSON(http.StatusOK, gin.H{
			"accounts": accounts,
		})
	}
}

// GetPaymentMethods retrieves connected bank accounts
func GetPaymentMethods(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("userID")
		if userID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
			return
		}

		if plaidClient == nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Plaid service unavailable"})
			return
		}

		// TODO: Retrieve access token from your database for this user
		accessToken := c.GetHeader("X-Access-Token")
		if accessToken == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Access token required"})
			return
		}

		ctx := context.Background()
		accounts, err := plaidClient.GetAccounts(ctx, accessToken)
		if err != nil {
			plaidClient.LogAPIInteraction(ctx, "/accounts/get", userID, false, err.Error())
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get payment methods"})
			return
		}

		plaidClient.LogAPIInteraction(ctx, "/accounts/get", userID, true, "Payment methods retrieved successfully")

		c.JSON(http.StatusOK, gin.H{
			"payment_methods": accounts,
		})
	}
}

// VerifyPaymentMethod verifies a bank account
func VerifyPaymentMethod(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("userID")
		if userID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
			return
		}

		var request struct {
			AccountID string `json:"account_id" binding:"required"`
		}

		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// TODO: Implement account verification logic
		// This could involve micro-deposits or instant verification via Plaid

		c.JSON(http.StatusOK, gin.H{
			"message":    "Account verification initiated",
			"account_id": request.AccountID,
			"status":     "pending_verification",
		})
	}
}

// CreateTransfer creates a new transfer (money in/out)
func CreateTransfer(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		var request struct {
			UserID      string  `json:"user_id" binding:"required"`
			AccountID   string  `json:"account_id" binding:"required"`
			Amount      float64 `json:"amount" binding:"required,gt=0"`
			Type        string  `json:"type" binding:"required"` // "money_in" or "money_out"
			Description string  `json:"description"`
		}

		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		if plaidClient == nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Plaid service unavailable"})
			return
		}

		ctx := context.Background()
		
		// Validate user consent
		if err := plaidClient.ValidateUserConsent(ctx, request.UserID, "create_transfer"); err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "User consent required"})
			return
		}

		// TODO: Implement actual transfer logic with your payment processor
		// This would use the verified account data from Plaid with processors like Dwolla, Stripe ACH, etc.

		transferID := uuid.New().String()
		transfer := PlaidTransfer{
			TransferID:     transferID,
			SenderUserID:   request.UserID,
			Amount:         request.Amount,
			Description:    request.Description,
			Status:         "pending",
			CreatedAt:      time.Now(),
		}

		plaidClient.LogAPIInteraction(ctx, "create_transfer", request.UserID, true, "Transfer created successfully")

		c.JSON(http.StatusCreated, gin.H{
			"transfer": transfer,
			"message":  "Transfer created successfully",
		})
	}
}

// CreateP2PTransfer creates a peer-to-peer transfer
func CreateP2PTransfer(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		var request struct {
			SenderUserID   string  `json:"sender_user_id" binding:"required"`
			ReceiverUserID string  `json:"receiver_user_id" binding:"required"`
			Amount         float64 `json:"amount" binding:"required,gt=0"`
			Description    string  `json:"description"`
		}

		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		if plaidClient == nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Plaid service unavailable"})
			return
		}

		ctx := context.Background()
		
		// Validate consent for both users
		if err := plaidClient.ValidateUserConsent(ctx, request.SenderUserID, "p2p_transfer_send"); err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "Sender consent required"})
			return
		}
		
		if err := plaidClient.ValidateUserConsent(ctx, request.ReceiverUserID, "p2p_transfer_receive"); err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "Receiver consent required"})
			return
		}

		// TODO: Verify both users have verified accounts and sufficient balance
		// TODO: Implement actual P2P transfer logic with your payment processor

		transferID := uuid.New().String()
		transfer := PlaidTransfer{
			TransferID:     transferID,
			SenderUserID:   request.SenderUserID,
			ReceiverUserID: request.ReceiverUserID,
			Amount:         request.Amount,
			Description:    request.Description,
			Status:         "pending",
			CreatedAt:      time.Now(),
		}

		plaidClient.LogAPIInteraction(ctx, "create_p2p_transfer", request.SenderUserID, true, "P2P transfer created successfully")

		c.JSON(http.StatusCreated, gin.H{
			"transfer": transfer,
			"message":  "P2P transfer created successfully",
		})
	}
}

// GetTransfer retrieves transfer details
func GetTransfer(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		transferID := c.Param("transferID")
		if transferID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Transfer ID is required"})
			return
		}

		// TODO: Retrieve transfer from your database
		// This is a placeholder implementation

		transfer := PlaidTransfer{
			TransferID:   transferID,
			Amount:       100.00,
			Description:  "Test transfer",
			Status:       "completed",
			CreatedAt:    time.Now().Add(-1 * time.Hour),
			CompletedAt:  &[]time.Time{time.Now().Add(-30 * time.Minute)}[0],
		}

		c.JSON(http.StatusOK, gin.H{
			"transfer": transfer,
		})
	}
}

// GetTransfers retrieves transfer history for a user
func GetTransfers(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("userID")
		if userID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
			return
		}

		// Parse query parameters
		limitStr := c.DefaultQuery("limit", "50")
		limit, err := strconv.Atoi(limitStr)
		if err != nil || limit <= 0 {
			limit = 50
		}

		// TODO: Retrieve transfers from your database
		// This is a placeholder implementation

		transfers := []PlaidTransfer{
			{
				TransferID:   uuid.New().String(),
				SenderUserID: userID,
				Amount:       50.00,
				Description:  "Test transfer 1",
				Status:       "completed",
				CreatedAt:    time.Now().Add(-2 * time.Hour),
			},
			{
				TransferID:     uuid.New().String(),
				ReceiverUserID: userID,
				Amount:         25.00,
				Description:    "Test transfer 2",
				Status:         "completed",
				CreatedAt:      time.Now().Add(-1 * time.Hour),
			},
		}

		c.JSON(http.StatusOK, gin.H{
			"transfers": transfers,
			"count":     len(transfers),
		})
	}
}

// GetBalance retrieves account balances
func GetBalance(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("userID")
		if userID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
			return
		}

		if plaidClient == nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Plaid service unavailable"})
			return
		}

		// TODO: Retrieve access token from your database for this user
		accessToken := c.GetHeader("X-Access-Token")
		if accessToken == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Access token required"})
			return
		}

		ctx := context.Background()
		accounts, err := plaidClient.GetBalance(ctx, accessToken)
		if err != nil {
			plaidClient.LogAPIInteraction(ctx, "/accounts/balance/get", userID, false, err.Error())
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get balance"})
			return
		}

		plaidClient.LogAPIInteraction(ctx, "/accounts/balance/get", userID, true, "Balance retrieved successfully")

		c.JSON(http.StatusOK, gin.H{
			"accounts": accounts,
		})
	}
}

// GetTransactions retrieves transaction history
func GetTransactions(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("userID")
		if userID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
			return
		}

		if plaidClient == nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Plaid service unavailable"})
			return
		}

		// TODO: Retrieve access token from your database for this user
		accessToken := c.GetHeader("X-Access-Token")
		if accessToken == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Access token required"})
			return
		}

		// Parse date range
		startDateStr := c.DefaultQuery("start_date", time.Now().AddDate(0, -1, 0).Format("2006-01-02"))
		endDateStr := c.DefaultQuery("end_date", time.Now().Format("2006-01-02"))

		startDate, err := time.Parse("2006-01-02", startDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid start_date format"})
			return
		}

		endDate, err := time.Parse("2006-01-02", endDateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid end_date format"})
			return
		}

		ctx := context.Background()
		transactions, err := plaidClient.GetTransactions(ctx, accessToken, startDate, endDate)
		if err != nil {
			plaidClient.LogAPIInteraction(ctx, "/transactions/get", userID, false, err.Error())
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get transactions"})
			return
		}

		plaidClient.LogAPIInteraction(ctx, "/transactions/get", userID, true, "Transactions retrieved successfully")

		c.JSON(http.StatusOK, gin.H{
			"transactions": transactions,
			"count":        len(transactions),
		})
	}
}

// HandlePlaidWebhook handles Plaid webhook notifications
func HandlePlaidWebhook(plaidClient *PlaidClient) gin.HandlerFunc {
	return func(c *gin.Context) {
		var webhook struct {
			WebhookType         string `json:"webhook_type"`
			WebhookCode         string `json:"webhook_code"`
			ItemID              string `json:"item_id"`
			Error               interface{} `json:"error,omitempty"`
			NewTransactions     int    `json:"new_transactions,omitempty"`
			RemovedTransactions []string `json:"removed_transactions,omitempty"`
		}

		if err := c.ShouldBindJSON(&webhook); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		ctx := context.Background()
		
		// Log webhook received
		plaidClient.LogAPIInteraction(ctx, "webhook_received", webhook.ItemID, true, 
			"Webhook: "+webhook.WebhookType+"/"+webhook.WebhookCode)

		// Handle different webhook types
		switch webhook.WebhookType {
		case "TRANSACTIONS":
			switch webhook.WebhookCode {
			case "INITIAL_UPDATE", "HISTORICAL_UPDATE", "DEFAULT_UPDATE":
				// TODO: Sync new transactions for the item
				// You would typically:
				// 1. Find the user associated with this item_id
				// 2. Fetch new transactions using GetTransactions
				// 3. Store them in your database
				// 4. Notify the user if needed
			case "TRANSACTIONS_REMOVED":
				// TODO: Remove transactions that are no longer valid
			}
		case "ITEM":
			switch webhook.WebhookCode {
			case "ERROR":
				// TODO: Handle item errors (e.g., expired access token)
				// You might need to re-initialize Link flow for the user
			case "PENDING_EXPIRATION":
				// TODO: Notify user that they need to re-link their account
			}
		case "AUTH":
			switch webhook.WebhookCode {
			case "AUTOMATICALLY_VERIFIED":
				// TODO: Mark account as verified in your database
			case "VERIFICATION_EXPIRED":
				// TODO: Handle expired verification
			}
		}

		c.JSON(http.StatusOK, gin.H{
			"message": "Webhook processed successfully",
		})
	}
}

// GetStripeConnectAccount retrieves Stripe Connect account information
func GetStripeConnectAccount(c *gin.Context) {
	userID := c.Param("userID")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
		return
	}

	// Get Stripe client from context
	stripeClientInterface, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Stripe service unavailable"})
		return
	}
	stripeClient := stripeClientInterface.(*StripeClient)

	// Find user by ID
	userMutex.RLock()
	var user *User
	for _, u := range userStore {
		if u.ID == userID {
			user = u
			break
		}
	}
	userMutex.RUnlock()

	if user == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	if user.StripeConnectID == "" {
		c.JSON(http.StatusNotFound, gin.H{"error": "No Stripe Connect account found for user"})
		return
	}

	ctx := context.Background()
	connectAccount, err := stripeClient.GetConnectAccount(ctx, user.StripeConnectID)
	if err != nil {
		log.Printf("Failed to retrieve Stripe Connect account for user %s: %v", userID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve account information"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"account": connectAccount,
	})
}

// UpdateStripeConnectAccount updates Stripe Connect account individual information
func UpdateStripeConnectAccount(c *gin.Context) {
	userID := c.Param("userID")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
		return
	}

	var updateRequest IndividualInfo
	if err := c.ShouldBindJSON(&updateRequest); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get Stripe client from context
	stripeClientInterface, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Stripe service unavailable"})
		return
	}
	stripeClient := stripeClientInterface.(*StripeClient)

	// Find user by ID
	userMutex.RLock()
	var user *User
	for _, u := range userStore {
		if u.ID == userID {
			user = u
			break
		}
	}
	userMutex.RUnlock()

	if user == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	if user.StripeConnectID == "" {
		c.JSON(http.StatusNotFound, gin.H{"error": "No Stripe Connect account found for user"})
		return
	}

	ctx := context.Background()
	updatedAccount, err := stripeClient.UpdateConnectAccountIndividual(ctx, user.StripeConnectID, &updateRequest)
	if err != nil {
		log.Printf("Failed to update Stripe Connect account for user %s: %v", userID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update account information"})
		return
	}

	// Update user's account status
	userMutex.Lock()
	if updatedAccount.DetailsSubmitted && updatedAccount.ChargesEnabled && updatedAccount.PayoutsEnabled {
		user.StripeAccountStatus = "active"
	} else if updatedAccount.DetailsSubmitted {
		user.StripeAccountStatus = "pending_approval"
	} else {
		user.StripeAccountStatus = "pending_verification"
	}
	userStore[user.Email] = user
	userMutex.Unlock()

	stripeClient.LogAPIInteraction(ctx, "account_update", userID, true, "Account information updated successfully")

	c.JSON(http.StatusOK, gin.H{
		"account": updatedAccount,
		"status":  user.StripeAccountStatus,
	})
}

// CreateStripeAccountLink creates an account link for Stripe Connect onboarding
func CreateStripeAccountLink(c *gin.Context) {
	userID := c.Param("userID")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
		return
	}

	var linkRequest struct {
		RefreshURL string `json:"refresh_url" binding:"required"`
		ReturnURL  string `json:"return_url" binding:"required"`
	}

	if err := c.ShouldBindJSON(&linkRequest); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get Stripe client from context
	stripeClientInterface, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Stripe service unavailable"})
		return
	}
	stripeClient := stripeClientInterface.(*StripeClient)

	// Find user by ID
	userMutex.RLock()
	var user *User
	for _, u := range userStore {
		if u.ID == userID {
			user = u
			break
		}
	}
	userMutex.RUnlock()

	if user == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	if user.StripeConnectID == "" {
		c.JSON(http.StatusNotFound, gin.H{"error": "No Stripe Connect account found for user"})
		return
	}

	ctx := context.Background()
	accountLinkURL, err := stripeClient.CreateAccountLink(ctx, user.StripeConnectID, linkRequest.RefreshURL, linkRequest.ReturnURL)
	if err != nil {
		log.Printf("Failed to create account link for user %s: %v", userID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create account link"})
		return
	}

	stripeClient.LogAPIInteraction(ctx, "account_link_created", userID, true, "Account onboarding link created")

	c.JSON(http.StatusOK, gin.H{
		"account_link_url": accountLinkURL,
	})
}

// DeleteStripeConnectAccount deletes a Stripe Connect account
func DeleteStripeConnectAccount(c *gin.Context) {
	userID := c.Param("userID")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
		return
	}

	// Get Stripe client from context
	stripeClientInterface, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Stripe service unavailable"})
		return
	}
	stripeClient := stripeClientInterface.(*StripeClient)

	// Find user by ID
	userMutex.RLock()
	var user *User
	for _, u := range userStore {
		if u.ID == userID {
			user = u
			break
		}
	}
	userMutex.RUnlock()

	if user == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	if user.StripeConnectID == "" {
		c.JSON(http.StatusNotFound, gin.H{"error": "No Stripe Connect account found for user"})
		return
	}

	ctx := context.Background()
	err := stripeClient.DeleteConnectAccount(ctx, user.StripeConnectID)
	if err != nil {
		log.Printf("Failed to delete Stripe Connect account for user %s: %v", userID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete account"})
		return
	}

	// Update user record
	userMutex.Lock()
	user.StripeConnectID = ""
	user.StripeAccountStatus = ""
	userStore[user.Email] = user
	userMutex.Unlock()

	stripeClient.LogAPIInteraction(ctx, "account_deleted", userID, true, "Stripe Connect account deleted")

	c.JSON(http.StatusOK, gin.H{
		"message": "Stripe Connect account deleted successfully",
	})
}

// SendMoney handles sending money between users through Stripe Connect
func SendMoney(c *gin.Context) {
	var request struct {
		ReceiverEmail string  `json:"receiver_email" binding:"required,email"`
		Amount        float64 `json:"amount" binding:"required,gt=0"`
		Currency      string  `json:"currency" binding:"required"`
		Description   string  `json:"description"`
	}

	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request data",
			"details": err.Error(),
		})
		return
	}

	// Validate amount limits (minimum $0.50, maximum $10,000)
	if request.Amount < 0.50 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Amount too small",
			"details": "Minimum amount is $0.50",
		})
		return
	}
	
	if request.Amount > 10000.00 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Amount too large",
			"details": "Maximum amount is $10,000.00",
		})
		return
	}

	// Validate currency (only USD for now)
	if request.Currency != "usd" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Unsupported currency",
			"details": "Only USD is currently supported",
		})
		return
	}

	// Validate description length
	if len(request.Description) > 200 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Description too long",
			"details": "Description must be 200 characters or less",
		})
		return
	}

	// Get sender from JWT token
	senderEmail, exists := c.Get("email")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Prevent self-transfer
	if senderEmail.(string) == request.ReceiverEmail {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid transaction",
			"details": "Cannot send money to yourself",
		})
		return
	}

	// Get sender user
	userMutex.RLock()
	sender, exists := userStore[senderEmail.(string)]
	userMutex.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Sender not found",
			"details": "Your account could not be found",
		})
		return
	}

	if sender.StripeConnectID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Sender does not have a Stripe Connect account",
			"details": "You need to complete your payment account setup before sending money",
		})
		return
	}

	// Get receiver user
	userMutex.RLock()
	receiver, exists := userStore[request.ReceiverEmail]
	userMutex.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Receiver not found",
			"details": "The recipient email address is not registered in our system",
		})
		return
	}

	if receiver.StripeConnectID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Receiver does not have a Stripe Connect account",
			"details": "The recipient has not completed their payment account setup",
		})
		return
	}

	// Convert amount to cents (validate for overflow)
	if request.Amount > 92233720368547.75 { // Max int64 / 100
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Amount too large",
			"details": "The amount exceeds the maximum allowed value",
		})
		return
	}
	amountCents := int64(request.Amount * 100)

	// Get Stripe client from context
	stripeClient, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Stripe client not available"})
		return
	}

	// Process the send money transaction with comprehensive error handling
	transaction, err := stripeClient.(*StripeClient).ProcessSendMoneyTransaction(
		context.Background(),
		sender.StripeConnectID,
		receiver.StripeConnectID,
		amountCents,
		request.Currency,
		request.Description,
	)

	if err != nil {
		// Log the error for debugging
		log.Printf("Payment processing error: %v", err)
		
		// Provide user-friendly error messages based on error type
		errorMsg := "Failed to process payment"
		details := "Please try again later or contact support if the problem persists"
		
		if strings.Contains(err.Error(), "insufficient_funds") {
			errorMsg = "Insufficient funds"
			details = "You don't have enough balance to complete this transaction"
		} else if strings.Contains(err.Error(), "account_invalid") {
			errorMsg = "Account verification required"
			details = "Your payment account needs additional verification"
		} else if strings.Contains(err.Error(), "rate_limit") {
			errorMsg = "Too many requests"
			details = "Please wait a moment before trying again"
		} else if strings.Contains(err.Error(), "api_key") {
			errorMsg = "Service temporarily unavailable"
			details = "Our payment service is experiencing issues. Please try again later"
		}
		
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": errorMsg,
			"details": details,
		})
		return
	}

	// Add receiver email to response
	transaction.ReceiverEmail = request.ReceiverEmail

	// Success response with transaction details
	c.JSON(http.StatusOK, gin.H{
		"message":       "Money sent successfully",
		"transaction":   transaction,
		"amount":        request.Amount,
		"currency":      request.Currency,
		"receiver":      request.ReceiverEmail,
		"description":   request.Description,
		"status":        "completed",
	})
}

// GetTransactionHistory retrieves transaction history for a user
func GetTransactionHistory(c *gin.Context) {
	// Get user from JWT token
	userEmail, exists := c.Get("email")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
			"details": "Please log in to view your transaction history",
		})
		return
	}

	// Validate email format
	if userEmail == nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid user session",
			"details": "Please log in again",
		})
		return
	}

	// Get user
	userMutex.RLock()
	user, exists := userStore[userEmail.(string)]
	userMutex.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "User not found",
			"details": "Your account could not be found",
		})
		return
	}

	if user.StripeConnectID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "User does not have a Stripe Connect account",
			"details": "You need to complete your payment account setup to view transaction history",
		})
		return
	}

	// Get Stripe client from context
	stripeClient, exists := c.Get("stripeClient")
	if !exists {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Service temporarily unavailable",
			"details": "Payment service is not available. Please try again later",
		})
		return
	}

	// Get account balance with error handling
	balance, err := stripeClient.(*StripeClient).GetAccountBalance(context.Background(), user.StripeConnectID)
	if err != nil {
		log.Printf("Failed to get account balance for user %s: %v", user.Email, err)
		
		// Provide user-friendly error messages based on error type
		errorMsg := "Failed to retrieve account information"
		details := "Please try again later or contact support if the problem persists"
		
		if strings.Contains(err.Error(), "account_invalid") {
			errorMsg = "Account verification required"
			details = "Your payment account needs additional verification"
		} else if strings.Contains(err.Error(), "rate_limit") {
			errorMsg = "Too many requests"
			details = "Please wait a moment before trying again"
		} else if strings.Contains(err.Error(), "api_key") {
			errorMsg = "Service temporarily unavailable"
			details = "Our payment service is experiencing issues. Please try again later"
		}
		
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": errorMsg,
			"details": details,
		})
		return
	}

	// Success response with enhanced information
	c.JSON(http.StatusOK, gin.H{
		"user_id":     user.ID,
		"email":       user.Email,
		"balance":     balance,
		"account_id":  user.StripeConnectID,
		"status":      "active",
		"message":     "Account information retrieved successfully",
		"retrieved_at": time.Now().UTC(),
	})
}