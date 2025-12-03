/**
 * Test Script: Simulate Consumption Request
 * 
 * This calls your testConsumptionRequest function to simulate
 * what happens when Apple sends a CONSUMPTION_REQUEST
 */

const https = require('https');

// Configuration
const PROJECT_ID = 'thrift-882cb';
const FUNCTION_NAME = 'testConsumptionRequest';
const REGION = 'us-central1';
const TRANSACTION_ID = '14'; // Change this to test different transactions

const url = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${FUNCTION_NAME}`;

console.log('🧪 SIMULATING CONSUMPTION REQUEST');
console.log('📡 Function URL:', url);
console.log('🔖 Transaction ID:', TRANSACTION_ID);
console.log('\n⏳ Sending request...\n');

// Prepare request data
const requestData = JSON.stringify({
  data: {
    transactionId: TRANSACTION_ID
  }
});

// Parse URL
const urlObj = new URL(url);

// Make request
const options = {
  hostname: urlObj.hostname,
  path: urlObj.pathname,
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': requestData.length
  }
};

const req = https.request(options, (res) => {
  console.log('✅ Response Status:', res.statusCode);
  
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log('\n📦 Response:');
    try {
      const parsed = JSON.parse(data);
      
      if (parsed.result) {
        console.log('\n✅ SUCCESS!');
        console.log('\n📊 Consumption Data:', JSON.stringify(parsed.result.consumptionData, null, 2));
        console.log('\n📄 Firestore Document ID:', parsed.result.firestoreDocId);
        console.log('\n🔗 Check Firestore:');
        console.log('   ', parsed.result.instructions.checkFirestore);
      } else if (parsed.error) {
        console.log('\n❌ ERROR:', parsed.error.message);
      } else {
        console.log(JSON.stringify(parsed, null, 2));
      }
    } catch (e) {
      console.log(data);
    }
    
    console.log('\n' + '='.repeat(60));
    console.log('🎯 WHAT TO CHECK NOW:');
    console.log('='.repeat(60));
    console.log('');
    console.log('1. Firestore Collection:');
    console.log('   https://console.firebase.google.com/project/thrift-882cb/firestore');
    console.log('   → Look for "consumption_requests" collection');
    console.log('   → Should see a new document with your transaction data');
    console.log('');
    console.log('2. Function Logs:');
    console.log('   https://console.firebase.google.com/project/thrift-882cb/functions/logs');
    console.log('   → Look for testConsumptionRequest logs');
    console.log('   → Should see aggregated usage data');
    console.log('');
    console.log('3. What the data shows:');
    console.log('   - Account tenure (how long user has been subscribed)');
    console.log('   - Play time (how much they used the app)');
    console.log('   - Consumption status (how much value they got)');
    console.log('   - Custom usage data (API calls, costs, features used)');
    console.log('');
    console.log('='.repeat(60));
  });
});

req.on('error', (error) => {
  console.error('\n❌ Error:', error.message);
  console.log('\nTroubleshooting:');
  console.log('- Make sure function is deployed');
  console.log('- Check that transaction exists in Firestore');
  console.log('- Verify function URL is correct');
});

// Send the request
req.write(requestData);
req.end();

