package main

import (
    "net/http"
    "os"
    "strings"

    "firebase.google.com/go/v4/auth"
    "github.com/gin-gonic/gin"
)

// CORSMiddleware handles Cross-Origin Resource Sharing
func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		allowedOrigins := os.Getenv("ALLOWED_ORIGINS")
		if allowedOrigins == "" {
			allowedOrigins = "*"
		}

		c.Header("Access-Control-Allow-Origin", allowedOrigins)
		c.Header("Access-Control-Allow-Credentials", "true")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Header("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE, PATCH")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

// AuthMiddleware validates Firebase ID tokens
func AuthMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
            c.Abort()
            return
        }

        tokenString := strings.TrimPrefix(authHeader, "Bearer ")
        if tokenString == authHeader {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization header format"})
            c.Abort()
            return
        }

        if v, ok := c.Get("firebaseAuth"); ok {
            fbAuth := v.(*auth.Client)
            idToken, err := fbAuth.VerifyIDToken(c.Request.Context(), tokenString)
            if err == nil && idToken != nil {
                c.Set("userID", idToken.UID)
                if email, ok := idToken.Claims["email"].(string); ok {
                    c.Set("email", email)
                }
                c.Next()
                return
            }
        }
        c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid Firebase token"})
        c.Abort()
        return
    }
}

// GenerateJWT creates a new JWT token for a user
func GenerateJWT(userID, email, userHandle string) (string, error) {
    return "", nil
}