package main

import (
    "context"
    "log"
    "os"

    "cloud.google.com/go/firestore"
    firebase "firebase.google.com/go/v4"
    "firebase.google.com/go/v4/auth"
    "github.com/gin-contrib/cors"
    "github.com/gin-gonic/gin"
    "github.com/joho/godotenv"
    "google.golang.org/api/option"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using system environment variables")
	}

	// Initialize Plaid client
	plaidClient, err := NewPlaidClient()
	if err != nil {
		log.Printf("Failed to initialize Plaid client: %v", err)
		// Continue without Plaid client - endpoints will return service unavailable
	}

	// Test Plaid connection if client is available
	if plaidClient != nil {
		ctx := context.Background()
		if err := plaidClient.TestConnection(ctx); err != nil {
			log.Printf("Plaid connection test failed: %v", err)
		} else {
			log.Println("Plaid connection test successful")
		}
	}

    // Initialize Stripe client
    stripeClient, err := NewStripeClient()
    if err != nil {
        log.Printf("Failed to initialize Stripe client: %v", err)
        // Continue without Stripe client - endpoints will return service unavailable
    } else {
        log.Println("Stripe client initialized successfully")
    }

    // Initialize Firebase app, Auth, and Firestore
    var fbAuth *auth.Client
    var fsClient *firestore.Client
    {
        ctx := context.Background()
        var app *firebase.App
        credsPath := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")
        var appErr error
        if credsPath != "" {
            app, appErr = firebase.NewApp(ctx, nil, option.WithCredentialsFile(credsPath))
        } else {
            app, appErr = firebase.NewApp(ctx, nil)
        }
        if appErr != nil {
            log.Printf("Failed to initialize Firebase app: %v", appErr)
        } else {
            fbAuth, err = app.Auth(ctx)
            if err != nil {
                log.Printf("Failed to initialize Firebase Auth: %v", err)
            } else {
                log.Println("Firebase Auth initialized successfully")
            }

            projectID := os.Getenv("FIREBASE_PROJECT_ID")
            if projectID == "" {
                log.Println("FIREBASE_PROJECT_ID not set; Firestore will be unavailable")
            } else {
                fsClient, err = firestore.NewClient(ctx, projectID)
                if err != nil {
                    log.Printf("Failed to initialize Firestore: %v", err)
                } else {
                    log.Println("Firestore client initialized successfully")
                }
            }
        }
    }

	// Initialize Gin router
	r := gin.Default()

	// Configure CORS
	config := cors.DefaultConfig()
	config.AllowOrigins = []string{"*"} // In production, specify exact origins
	config.AllowMethods = []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}
	config.AllowHeaders = []string{"Origin", "Content-Type", "Accept", "Authorization", "Stripe-Signature"}
	r.Use(cors.New(config))

    // Middleware to inject clients into context
    r.Use(func(c *gin.Context) {
        if plaidClient != nil {
            c.Set("plaidClient", plaidClient)
        }
        if stripeClient != nil {
            c.Set("stripeClient", stripeClient)
        }
        if fbAuth != nil {
            c.Set("firebaseAuth", fbAuth)
        }
        if fsClient != nil {
            c.Set("firestore", fsClient)
        }
        c.Next()
    })

    // Health check endpoint
    r.GET("/health", HealthCheck)

    // Authentication routes
    auth := r.Group("/auth")
    {
        auth.POST("/login", Login)
        auth.POST("/register", Register)
    }

    // Apply auth middleware to protected routes (can be refined per-group)
    r.Use(AuthMiddleware())

	// Plaid Link routes
	plaidLink := r.Group("/plaid")
	{
		plaidLink.POST("/link-token", CreateLinkToken(plaidClient))
		plaidLink.POST("/exchange-token", ExchangePublicToken(plaidClient))
	}

	// Account management routes
	accounts := r.Group("/accounts")
	{
		accounts.POST("/", CreateAccount(plaidClient))
		accounts.GET("/:userID", GetAccount(plaidClient))
		accounts.PUT("/:userID", UpdateAccount(plaidClient))
		accounts.GET("/:userID/auth", GetAuthData(plaidClient))
	}

	// Payment methods routes (bank accounts via Plaid)
	paymentMethods := r.Group("/payment-methods")
	{
		paymentMethods.GET("/:userID", GetPaymentMethods(plaidClient))
		paymentMethods.POST("/:userID/verify", VerifyPaymentMethod(plaidClient))
	}

	// Transfer routes (Legacy - using existing handlers)
	transfers := r.Group("/transfers")
	{
		transfers.POST("/", CreateTransfer(plaidClient))
		transfers.POST("/p2p", CreateP2PTransfer(plaidClient))
		transfers.GET("/:transferID", GetTransfer(plaidClient))
		transfers.GET("/user/:userID", GetTransfers(plaidClient))
	}

	// Stripe-powered customer management routes
	customers := r.Group("/stripe/customers")
	{
		customers.POST("/", CreateStripeCustomer)
	}

	// Stripe Connect onboarding routes
	connect := r.Group("/stripe/connect")
	{
		connect.POST("/account", CreateConnectAccount)
		connect.POST("/account-link", CreateConnectAccountLink)
		connect.GET("/account/:accountID/status", GetConnectAccountStatus)
	}

	// Stripe-powered payment methods routes (integrating Plaid verification)
	stripePaymentMethods := r.Group("/stripe/payment-methods")
	{
		stripePaymentMethods.POST("/from-plaid", CreatePaymentMethodFromPlaid)
	}

	// Setup intent route (save payment methods)
	r.POST("/stripe/setup-intent", CreateSetupIntentForCustomer)

	// Stripe-powered transfer routes
	stripeTransfers := r.Group("/stripe/transfers")
	{
		stripeTransfers.POST("/", CreateTransferWithStripe)
		stripeTransfers.POST("/p2p", CreateP2PTransferWithStripe)
		stripeTransfers.POST("/confirm", ConfirmTransfer)
		stripeTransfers.GET("/:id/status", GetTransferStatus)
	}

	// Balance routes
	balance := r.Group("/balance")
	{
		balance.GET("/:userID", GetBalance(plaidClient))
	}

	// Transaction routes
	transactions := r.Group("/transactions")
	{
		transactions.GET("/:userID", GetTransactions(plaidClient))
	}

	// Webhook routes
	webhooks := r.Group("/webhooks")
	{
		webhooks.POST("/plaid", HandlePlaidWebhook(plaidClient))
		webhooks.POST("/stripe", HandleStripeWebhook)
	}

	// P2P payments via Stripe (platform charge then transfer)
	r.POST("/payments/p2p/initiate", InitiateP2PPayment)

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}