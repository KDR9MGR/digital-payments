#!/bin/bash

echo "🔍 Validating Sila Configuration..."
echo "=================================="

# Check backend environment file
echo "📁 Backend Configuration (.env):"
if [ -f "backend/.env" ]; then
    echo "✅ .env file exists"
    
    # Check each required variable
    if grep -q "SILA_APP_HANDLE=d_p" backend/.env; then
        echo "✅ SILA_APP_HANDLE is set to: d_p"
    else
        echo "❌ SILA_APP_HANDLE not properly configured"
    fi
    
    if grep -q "SILA_CLIENT_ID=eZmAMpxhGtgFCfpqX_Hy4m6Qh2Ih4JxOiX9r5IuzsHo" backend/.env; then
        echo "✅ SILA_CLIENT_ID is configured"
    else
        echo "❌ SILA_CLIENT_ID not properly configured"
    fi
    
    if grep -q "SILA_CLIENT_SECRET=Ocac22fkY36dHyg_XJK80Z26Y98TxfsRGV-YRJDUvfPms-8jLsTqa33GzWKaXa7mm8XX_arGTmAk7KEsw09tBw" backend/.env; then
        echo "✅ SILA_CLIENT_SECRET is configured"
    else
        echo "❌ SILA_CLIENT_SECRET not properly configured"
    fi
    
    if grep -q "SILA_PRIVATE_KEY=your_private_key_here_REQUIRED" backend/.env; then
        echo "⚠️  SILA_PRIVATE_KEY is placeholder - NEEDS TO BE SET"
    elif grep -q "SILA_PRIVATE_KEY=" backend/.env && ! grep -q "SILA_PRIVATE_KEY=your_private_key_here_REQUIRED" backend/.env; then
        echo "✅ SILA_PRIVATE_KEY appears to be set"
    else
        echo "❌ SILA_PRIVATE_KEY not configured"
    fi
    
    if grep -q "SILA_BASE_URL=https://sandbox.silamoney.com/0.2" backend/.env; then
        echo "✅ SILA_BASE_URL is set to sandbox"
    else
        echo "❌ SILA_BASE_URL not properly configured"
    fi
else
    echo "❌ backend/.env file not found"
fi

echo ""
echo "📱 Flutter Configuration:"
if [ -f "lib/config/sila_config.dart" ]; then
    echo "✅ sila_config.dart exists"
    
    if grep -q "const defaultHandle = 'd_p'" lib/config/sila_config.dart; then
        echo "✅ App handle configured in Flutter"
    else
        echo "❌ App handle not configured in Flutter"
    fi
    
    if grep -q "const defaultClientId = 'eZmAMpxhGtgFCfpqX_Hy4m6Qh2Ih4JxOiX9r5IuzsHo'" lib/config/sila_config.dart; then
        echo "✅ Client ID configured in Flutter"
    else
        echo "❌ Client ID not configured in Flutter"
    fi
    
    if grep -q "const defaultClientSecret = 'Ocac22fkY36dHyg_XJK80Z26Y98TxfsRGV-YRJDUvfPms-8jLsTqa33GzWKaXa7mm8XX_arGTmAk7KEsw09tBw'" lib/config/sila_config.dart; then
        echo "✅ Client Secret configured in Flutter"
    else
        echo "❌ Client Secret not configured in Flutter"
    fi
else
    echo "❌ lib/config/sila_config.dart not found"
fi

echo ""
echo "🔧 Next Steps:"
echo "=============="
echo "1. ⚠️  CRITICAL: You need to obtain the SILA_PRIVATE_KEY from Sila"
echo "2. 📝 Update backend/.env with the actual private key"
echo "3. 🧪 Test the configuration by running the backend"
echo "4. 📱 Test Flutter app connectivity"

echo ""
echo "📞 To get your private key:"
echo "- Contact Sila support or check your Sila dashboard"
echo "- The private key is required for API authentication"
echo "- It should be a cryptographic key (not the same as client secret)"

echo ""
echo "🚀 Once you have the private key, run:"
echo "cd backend && go run ."