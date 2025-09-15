#!/usr/bin/env node

/**
 * Moov OAuth2 Credentials Test Script
 * This script tests if your Moov OAuth2 credentials are configured correctly
 */

const functions = require('firebase-functions');
const axios = require('axios');

// Test configuration
const MOOV_BASE_URL = 'https://api.moov.io';

async function testMoovCredentials() {
    console.log('🧪 Testing Moov OAuth2 Credentials');
    console.log('==================================');
    console.log('');

    try {
        // Get configuration
        const config = functions.config();
        
        if (!config.moov) {
            console.log('❌ No Moov configuration found in Firebase Functions config');
            console.log('   Run: ./setup_moov_credentials.sh to set up credentials');
            return false;
        }

        const { client_id, client_secret, public_key, private_key, platform_account_id } = config.moov;

        // Check required fields
        const missing = [];
        if (!client_id) missing.push('client_id');
        if (!client_secret) missing.push('client_secret');
        if (!public_key) missing.push('public_key');
        if (!private_key) missing.push('private_key');
        if (!platform_account_id) missing.push('platform_account_id');

        if (missing.length > 0) {
            console.log(`❌ Missing required credentials: ${missing.join(', ')}`);
            console.log('   Run: ./setup_moov_credentials.sh to set up missing credentials');
            return false;
        }

        console.log('✅ All required credentials are present');
        console.log('');

        // Test OAuth2 token generation
        console.log('🔑 Testing OAuth2 token generation...');
        
        const tokenResponse = await axios.post(`${MOOV_BASE_URL}/oauth2/token`, {
            grant_type: 'client_credentials',
            scope: 'accounts.write transfers.write payment-methods.write'
        }, {
            auth: {
                username: client_id,
                password: client_secret
            },
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            timeout: 10000
        });

        if (tokenResponse.data && tokenResponse.data.access_token) {
            console.log('✅ OAuth2 token generated successfully');
            console.log(`   Token type: ${tokenResponse.data.token_type}`);
            console.log(`   Expires in: ${tokenResponse.data.expires_in} seconds`);
            console.log('');

            // Test API call with token
            console.log('🌐 Testing API call with token...');
            
            const apiResponse = await axios.get(`${MOOV_BASE_URL}/accounts/${platform_account_id}`, {
                headers: {
                    'Authorization': `Bearer ${tokenResponse.data.access_token}`,
                    'Content-Type': 'application/json'
                },
                timeout: 10000
            });

            if (apiResponse.data && apiResponse.data.accountID) {
                console.log('✅ API call successful');
                console.log(`   Account ID: ${apiResponse.data.accountID}`);
                console.log(`   Account Type: ${apiResponse.data.accountType}`);
                console.log(`   Display Name: ${apiResponse.data.displayName || 'N/A'}`);
                console.log('');
                console.log('🎉 All tests passed! Your Moov credentials are working correctly.');
                return true;
            } else {
                console.log('❌ API call failed - invalid response format');
                return false;
            }

        } else {
            console.log('❌ Failed to generate OAuth2 token - invalid response');
            return false;
        }

    } catch (error) {
        console.log('❌ Test failed with error:');
        
        if (error.response) {
            console.log(`   Status: ${error.response.status}`);
            console.log(`   Message: ${error.response.data?.message || error.response.statusText}`);
            
            if (error.response.status === 401) {
                console.log('   This usually means your client_id or client_secret is incorrect');
            } else if (error.response.status === 404) {
                console.log('   This usually means your platform_account_id is incorrect');
            }
        } else {
            console.log(`   Error: ${error.message}`);
        }
        
        console.log('');
        console.log('🔧 Troubleshooting:');
        console.log('   1. Verify your credentials in the Moov Dashboard');
        console.log('   2. Make sure your API key has the required scopes');
        console.log('   3. Check that your platform account ID is correct');
        console.log('   4. Run: ./setup_moov_credentials.sh to reconfigure');
        
        return false;
    }
}

// Run the test
if (require.main === module) {
    testMoovCredentials().then(success => {
        process.exit(success ? 0 : 1);
    });
}

module.exports = { testMoovCredentials };