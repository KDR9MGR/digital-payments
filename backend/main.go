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

    

    // Webhook routes
    webhooks := r.Group("/webhooks")
    {
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