#!/bin/bash

# Moov API Keys Setup Script
# This script helps you configure Moov API keys for your Firebase Functions

set -e

echo "🚀 Moov API Keys Setup"
echo "======================"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed."
    echo "Please install it first: npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI is installed"
echo ""

# Check if user is logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo "❌ You are not logged in to Firebase."
    echo "Please run: firebase login"
    exit 1
fi

echo "✅ You are logged in to Firebase"
echo ""

echo "📋 Required Moov Credentials:"
echo "   1. Public Key (API Key)"
echo "   2. Private Key (Secret Key)"
echo "   3. Platform Account ID (optional, for facilitator accounts)"
echo ""
echo "🔍 Where to find these:"
echo "   • Go to https://dashboard.moov.io"
echo "   • Navigate to 'Developers' → 'API Keys'"
echo "   • Create or view your API key pair"
echo "   • For Platform Account ID: Go to 'Account' section"
echo ""

read -p "Do you have your Moov API keys ready? (y/n): " ready
if [[ $ready != "y" && $ready != "Y" ]]; then
    echo "Please gather your credentials and run this script again."
    exit 1
fi

echo ""
echo "🔧 Setting up Moov configuration..."
echo ""

# Get Moov Public Key
read -p "Enter your Moov Public Key: " moov_public_key
if [[ -z "$moov_public_key" ]]; then
    echo "❌ Public Key is required"
    exit 1
fi

# Get Moov Private Key
read -s -p "Enter your Moov Private Key (hidden): " moov_private_key
echo ""
if [[ -z "$moov_private_key" ]]; then
    echo "❌ Private Key is required"
    exit 1
fi

# Get Platform Account ID (optional)
read -p "Enter your Platform Account ID (optional, press Enter to skip): " platform_account_id

# Get environment (sandbox/production)
echo ""
echo "Select environment:"
echo "1) Sandbox (https://api.moov.io)"
echo "2) Production (https://api.moov.io)"
read -p "Choose environment (1 or 2, default: 1): " env_choice

base_url="https://api.moov.io"
if [[ "$env_choice" == "2" ]]; then
    echo "⚠️  Using production environment"
else
    echo "🧪 Using sandbox environment"
fi

echo ""
echo "🔧 Configuring Firebase Functions..."

# Set the configuration
firebase functions:config:set \
    moov.public_key="$moov_public_key" \
    moov.private_key="$moov_private_key" \
    moov.base_url="$base_url"

# Set platform account ID if provided
if [[ -n "$platform_account_id" ]]; then
    firebase functions:config:set moov.platform_account_id="$platform_account_id"
    echo "✅ Platform Account ID configured"
fi

echo ""
echo "✅ Moov configuration completed!"
echo ""
echo "📝 Next steps:"
echo "   1. Deploy your functions: firebase deploy --only functions"
echo "   2. Test the integration using your app"
echo ""
echo "🔍 To verify configuration:"
echo "   firebase functions:config:get"
echo ""
echo "📚 For more information, see:"
echo "   • Moov API Documentation: https://docs.moov.io"
echo "   • Your project's MOOV_SETUP.md file"
echo ""