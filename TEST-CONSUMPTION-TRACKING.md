# 🧪 Testing Your Consumption Tracking System

## ✅ Quick Test Checklist

### 1. Test Transaction Recording
- [ ] Make a test purchase in sandbox
- [ ] Check Firestore `transactions` collection
- [ ] Verify transaction data is complete

### 2. Test Play Time Tracking
- [ ] Use app for 2-3 minutes
- [ ] Put app in background
- [ ] Check Xcode console logs

### 3. Test Subscription Usage
- [ ] Create a thrift analysis
- [ ] Check for "Subscription marked as USED" log
- [ ] Verify in transaction data

### 4. Test Webhook Response
- [ ] Simulate Apple's consumption request
- [ ] Check Firebase function logs
- [ ] Verify response format

---

## 📱 Test 1: Transaction Recording

### Steps:
1. **Make a Sandbox Purchase:**
   - Use a sandbox test account
   - Purchase any subscription
   - Wait for success confirmation

2. **Check Firestore:**
   - Go to: https://console.firebase.google.com/project/thrift-882cb/firestore
   - Navigate to `transactions` collection
   - Look for your transaction ID

3. **Verify Transaction Data:**
   Your transaction should include:
   ```json
   {
     "transactionId": "2000000...",
     "originalTransactionId": "2000000...",
     "productId": "com.thrifty.thrifty.unlimited.monthly",
     "purchaseDate": 1234567890,
     "expiresDate": 1234567890,
     "price": 79.00,
     "currency": "USD",
     "userId": "firebase_uid",
     "userEmail": "test@example.com",
     "revenueCatUserId": "test@example.com",
     "usedSubscription": false,  // Will be true after using features
     "playTimeSeconds": 0,        // Will increase over time
     "recordedAt": 1234567890,
     "updatedAt": 1234567890
   }
   ```

---

## ⏱️ Test 2: Play Time Tracking

### Steps:
1. **Open Xcode Console:**
   - Run your app from Xcode
   - Keep console visible

2. **Use the App:**
   - Navigate around for 2-3 minutes
   - Use different features

3. **Check Logs:**
   Look for these log messages:
   ```
   📊 ConsumptionRequestService: Session started
   📊 Loaded play time: 0s, used subscription: false
   ```

4. **Put App in Background:**
   - Swipe up to home screen
   - Look for:
   ```
   📱 App moved to background
   📊 ConsumptionRequestService: Session ended. Duration: 120s, Total: 120s
   📊 Saved play time: 120s
   📊 Syncing X consumption events to server...
   ✅ Successfully synced consumption data to server
   ```

5. **Reopen App:**
   - Should see your total play time loaded:
   ```
   📊 Loaded play time: 120s, used subscription: false
   ```

---

## 🎯 Test 3: Subscription Usage Tracking

### Steps:
1. **Create a Thrift Analysis:**
   - Open camera
   - Take photo of an item
   - Start analysis

2. **Watch Console:**
   Look for:
   ```
   📊 Subscription marked as USED
   📊 Feature usage tracked: price_analysis
   📊 OpenAI call tracked: successful, cost: 15 cents
   📊 SerpAPI call tracked: successful, cost: 5 cents
   📊 Firebase call tracked: successful, cost: 1 cents
   ```

3. **Verify in Transaction Data:**
   - The `usedSubscription` field should now be `true`
   - This gets synced automatically

---

## 🌐 Test 4: Webhook Response (Advanced)

### Option A: Wait for Real Chargeback (Not Recommended)
- Wait for an actual user chargeback
- Apple will send notification to your webhook
- Check Firebase function logs

### Option B: Test with Sandbox Notification (Recommended)

I'll create a test script for you...

---

## 🔍 Monitoring & Verification

### Firebase Console Checks:

#### 1. **Firestore Data:**
https://console.firebase.google.com/project/thrift-882cb/firestore

Collections to check:
- `transactions` - All purchase transactions
- `user_consumption` - User usage events
- `consumption_requests` - Apple's requests (will populate on chargebacks)

#### 2. **Function Logs:**
https://console.firebase.google.com/project/thrift-882cb/functions

Look for:
- `recordTransaction` - Should show transaction saves
- `syncConsumptionData` - Should show data syncs
- `appleConsumptionWebhook` - Will show Apple's requests

---

## 🎯 Expected Results

### After Purchase:
✅ Transaction in Firestore  
✅ All fields populated  
✅ `usedSubscription: false` initially

### After Using Features:
✅ `usedSubscription: true` in transaction  
✅ Consumption events syncing every 10 events  
✅ Automatic sync every 5 minutes

### After Background:
✅ Session ended log  
✅ Play time saved  
✅ Data synced to server

### On Chargeback (Future):
✅ Apple sends CONSUMPTION_REQUEST  
✅ Your webhook receives it  
✅ Data aggregated from Firestore  
✅ Response sent to Apple automatically

---

## 🐛 Troubleshooting

### "Transaction not saved"
- Check Firebase function logs for errors
- Verify internet connection during purchase
- Check if `recordTransaction` function is deployed

### "Play time not tracking"
- Make sure app is running from Xcode to see logs
- Check if `ConsumptionRequestService` is initialized
- Verify app lifecycle handlers are working

### "Subscription not marked as used"
- Make sure you're using premium features
- Check that `markSubscriptionAsUsed()` is being called
- Look for the log message in console

### "Data not syncing"
- Check internet connection
- Look for sync errors in console
- Verify Firebase Functions are accessible

---

## 📊 Success Criteria

Your system is working correctly if:

1. ✅ Transactions appear in Firestore after purchase
2. ✅ Play time increases with app usage
3. ✅ Subscription marked as used after premium feature use
4. ✅ Data syncs automatically to server
5. ✅ Console shows all expected log messages
6. ✅ No errors in Firebase function logs

---

## 🚀 Ready for Production

Once all tests pass, your system is production-ready:
- All purchases will be automatically tracked
- Usage data will be continuously collected
- Apple will receive comprehensive data on chargebacks
- Your chargeback defense is fully operational! 🛡️

