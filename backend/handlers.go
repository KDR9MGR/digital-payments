package main

import (
    "context"
    "net/http"
    "strconv"
    "time"

    "cloud.google.com/go/firestore"
    "github.com/gin-gonic/gin"
    "github.com/google/uuid"
)

// HealthCheck returns the health status of the API
func HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "healthy",
		"timestamp": time.Now().UTC(),
		"service":   "digital-payments-backend",
	})
}

// Login handles user authentication
func Login(c *gin.Context) {
    uidVal, ok := c.Get("userID")
    if !ok {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
        return
    }
    emailVal, _ := c.Get("email")
    uid := uidVal.(string)
    email := ""
    if emailVal != nil {
        email = emailVal.(string)
    }
    if v, ok := c.Get("firestore"); ok {
        fs := v.(*firestore.Client)
        _, _ = fs.Collection("users").Doc(uid).Set(c.Request.Context(), map[string]interface{}{
            "uid":          uid,
            "email":        email,
            "updated_at":   time.Now(),
        }, firestore.MergeAll)
    }
    c.JSON(http.StatusOK, gin.H{"userID": uid, "email": email})
}

// Register handles user registration
func Register(c *gin.Context) {
    uidVal, ok := c.Get("userID")
    if !ok {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
        return
    }
    emailVal, _ := c.Get("email")
    uid := uidVal.(string)
    email := ""
    if emailVal != nil {
        email = emailVal.(string)
    }
    if v, ok := c.Get("firestore"); ok {
        fs := v.(*firestore.Client)
        _, _ = fs.Collection("users").Doc(uid).Set(c.Request.Context(), map[string]interface{}{
            "uid":          uid,
            "email":        email,
            "created_at":   time.Now(),
            "updated_at":   time.Now(),
        }, firestore.MergeAll)
    }
    c.JSON(http.StatusCreated, gin.H{"userID": uid, "email": email})
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