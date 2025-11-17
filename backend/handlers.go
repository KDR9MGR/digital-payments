package main

import (
    "net/http"
    "time"

    "cloud.google.com/go/firestore"
    "github.com/gin-gonic/gin"
)

func HealthCheck(c *gin.Context) {
    c.JSON(http.StatusOK, gin.H{
        "status":    "healthy",
        "timestamp": time.Now().UTC(),
        "service":   "digital-payments-backend",
    })
}

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
            "uid":        uid,
            "email":      email,
            "updated_at": time.Now(),
        }, firestore.MergeAll)
    }
    c.JSON(http.StatusOK, gin.H{"userID": uid, "email": email})
}

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
            "uid":        uid,
            "email":      email,
            "created_at": time.Now(),
            "updated_at": time.Now(),
        }, firestore.MergeAll)
    }
    c.JSON(http.StatusCreated, gin.H{"userID": uid, "email": email})
}

