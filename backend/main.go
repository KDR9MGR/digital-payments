package main

import (
	"context"
	"log"
	"os"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
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

	// Stripe Connect account management routes
	stripeConnect := r.Group("/stripe/connect")
	{
		stripeConnect.GET("/account/:userID", GetStripeConnectAccount)
		stripeConnect.PUT("/account/:userID", UpdateStripeConnectAccount)
		stripeConnect.POST("/account/:userID/link", CreateStripeAccountLink)
		stripeConnect.DELETE("/account/:userID", DeleteStripeConnectAccount)
	}

	// Stripe-powered payment methods routes (integrating Plaid verification)
	stripePaymentMethods := r.Group("/stripe/payment-methods")
	{
		stripePaymentMethods.POST("/from-plaid", CreatePaymentMethodFromPlaid)
	}

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

	// Payment processing routes (requires authentication)
	payments := r.Group("/payments")
	payments.Use(AuthMiddleware()) // Ensure user is authenticated
	{
		payments.POST("/send", SendMoney)
		payments.POST("/receive", ReceiveMoney)
		payments.GET("/history", GetTransactionHistory)
	}

	// Webhook routes
	webhooks := r.Group("/webhooks")
	{
		webhooks.POST("/plaid", HandlePlaidWebhook(plaidClient))
		webhooks.POST("/stripe", HandleStripeWebhook)
	}

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