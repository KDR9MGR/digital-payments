package main

import (
    "context"
    "fmt"
)

type PlaidClient struct{}

type PlaidAccount struct {
    AccountID    string
    Name         string
    Type         string
    Subtype      string
    Mask         string
    RoutingNumber string
    AccountNumber string
}

func (pc *PlaidClient) GetAccounts(ctx context.Context, accessToken string) ([]PlaidAccount, error) {
    return nil, fmt.Errorf("not supported")
}

func (pc *PlaidClient) GetAuthData(ctx context.Context, accessToken string) ([]PlaidAccount, error) {
    return nil, fmt.Errorf("not supported")
}