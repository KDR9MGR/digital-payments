#!/usr/bin/env node

/**
 * Test script for Moov API Key authentication
 * This script tests the basic API key authentication with Moov
 */

const https = require('https');
const { URL } = require('url');

// Configuration - these should match your Firebase config
const MOOV_CONFIG = {
  baseURL: process.env.MOOV_BASE_URL || 'https://api.moov.io',
  publicKey: process.env.MOOV_PUBLIC_KEY,
  privateKey: process.env.MOOV_PRIVATE_KEY,
  platformAccountId: process.env.MOOV_PLATFORM_ACCOUNT_ID
};

// Create Basic Auth header
function createBasicAuthHeader() {
  if (!MOOV_CONFIG.publicKey || !MOOV_CONFIG.privateKey) {
    throw new Error('MOOV_PUBLIC_KEY and MOOV_PRIVATE_KEY environment variables are required');
  }
  
  const credentials = Buffer.from(`${MOOV_CONFIG.publicKey}:${MOOV_CONFIG.privateKey}`).toString('base64');
  return `Basic ${credentials}`;
}

// Get headers for Moov API requests
function moovHeaders() {
  return {
    'Authorization': createBasicAuthHeader(),
    'Content-Type': 'application/json',
    'X-Platform-Account-ID': MOOV_CONFIG.platformAccountId || ''
  };
}

/**
 * Test function to verify API key authentication
 */
async function testMoovApiKeys() {
  console.log('🔧 Testing Moov API Key Authentication...\n');
  
  return new Promise((resolve) => {
    try {
      // Test endpoint: List accounts
      const url = new URL('/accounts', MOOV_CONFIG.baseURL);
      const headers = moovHeaders();
      
      console.log('📡 Making request to:', url.toString());
      console.log('🔑 Using Basic Auth with public key:', MOOV_CONFIG.publicKey);
      console.log('🔒 Private key configured:', MOOV_CONFIG.privateKey ? 'Yes' : 'No');
      
      const options = {
        hostname: url.hostname,
        port: url.port || 443,
        path: url.pathname + '?count=1',
        method: 'GET',
        headers: headers
      };
      
      const req = https.request(options, (res) => {
        let data = '';
        
        res.on('data', (chunk) => {
          data += chunk;
        });
        
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            console.log('✅ SUCCESS! API Key authentication is working');
            console.log('📊 Response status:', res.statusCode);
            console.log('📋 Response data:', data);
            resolve(true);
          } else {
            console.log('❌ ERROR! API Key authentication failed');
            console.log('📊 Response status:', res.statusCode);
            console.log('📋 Response data:', data);
            resolve(false);
          }
        });
      });
      
      req.on('error', (error) => {
        console.log('❌ ERROR! API Key authentication failed');
        console.log('🔍 Error details:', error.message);
        resolve(false);
      });
      
      req.end();
    } catch (error) {
      console.log('❌ ERROR! API Key authentication failed');
      console.log('🔍 Error details:', error.message);
      resolve(false);
    }
  });
}

async function testMoovAuthentication() {
  console.log('🧪 Testing Moov API Key Authentication');
  console.log('=====================================');
  console.log('');

  try {
    console.log('📡 Testing API connection...');
    
    const success = await testMoovApiKeys();
    
    if (success) {
      console.log('✅ API Key authentication successful!');
      
      if (MOOV_CONFIG.platformAccountId) {
        console.log(`🏢 Platform Account ID: ${MOOV_CONFIG.platformAccountId}`);
      }
      
      console.log('');
      console.log('🎉 Moov API integration is working correctly!');
      console.log('');
      console.log('📝 Next steps:');
      console.log('   1. Deploy your Firebase Functions');
      console.log('   2. Test account creation from your app');
      console.log('   3. Test transfers and other operations');
    } else {
      throw new Error('API authentication test failed');
    }

  } catch (error) {
    console.error('❌ API Key authentication failed!');
    console.error('');
    
    console.error(`🐛 Error: ${error.message}`);
    
    console.error('');
    console.error('🔧 Troubleshooting:');
    console.error('   1. Verify your API keys are correct');
    console.error('   2. Check that your keys have the required permissions');
    console.error('   3. Ensure you\'re using the correct environment (sandbox/production)');
    
    process.exit(1);
  }
}

// Check if required environment variables are set
function checkEnvironment() {
  console.log('🔍 Checking environment variables...');
  
  const required = ['MOOV_PUBLIC_KEY', 'MOOV_PRIVATE_KEY'];
  const missing = required.filter(key => !process.env[key]);
  
  if (missing.length > 0) {
    console.error('❌ Missing required environment variables:');
    missing.forEach(key => console.error(`   - ${key}`));
    console.error('');
    console.error('💡 Set them like this:');
    console.error('   export MOOV_PUBLIC_KEY="your_public_key"');
    console.error('   export MOOV_PRIVATE_KEY="your_private_key"');
    console.error('   export MOOV_PLATFORM_ACCOUNT_ID="your_platform_id" # optional');
    console.error('');
    process.exit(1);
  }
  
  console.log('✅ Environment variables are set');
  console.log('');
}

// Main execution
async function main() {
  checkEnvironment();
  await testMoovAuthentication();
}

// Run the test
if (require.main === module) {
  main().catch(console.error);
}

module.exports = { testMoovAuthentication, createBasicAuthHeader, moovHeaders };