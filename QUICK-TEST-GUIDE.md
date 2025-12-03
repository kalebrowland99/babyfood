# 🚀 Quick Test Guide - 5 Minutes

## ✅ Your System is Ready!

Everything is configured and deployed. Here's how to test it:

---

## 🧪 Test 1: Quick Webhook Test (30 seconds)

Run the automated test script:

```bash
cd /Users/elianasilva/Desktop/thrift
node test-webhook.js
```

**Expected Result:**
```
✅ Response Status: 200
✅ Test PASSED! Webhook processed the consumption request successfully.
```

This confirms your webhook is:
- ✅ Accessible
- ✅ Processing Apple's requests
- ✅ Responding correctly

---

## 📱 Test 2: Make a Test Purchase (2 minutes)

1. **Run your app** in Xcode
2. **Watch the Console** for logs
3. **Make a sandbox purchase** (any subscription)
4. **Look for these logs:**

```
✅ Successfully purchased...
📊 Recording transaction: 2000001...
✅ Transaction recorded successfully
```

5. **Verify in Firestore:**
   - Open: https://console.firebase.google.com/project/thrift-882cb/firestore
   - Navigate to `transactions` collection
   - Find your transaction ID
   - Verify all fields are populated

---

## ⏱️ Test 3: Play Time Tracking (2 minutes)

1. **Use the app** for 2-3 minutes
2. **Navigate different screens**
3. **Put app in background** (swipe home)
4. **Check Console:**

```
📱 App moved to background
📊 Session ended. Duration: 120s, Total: 120s
📊 Saved play time: 120s
✅ Successfully synced consumption data to server
```

5. **Reopen the app:**

```
📊 Loaded play time: 120s, used subscription: false
```

---

## 🎯 Test 4: Subscription Usage (1 minute)

1. **Create a thrift analysis** (take photo of item)
2. **Check Console:**

```
📊 Subscription marked as USED
📊 Feature usage tracked: price_analysis
📊 OpenAI call tracked: successful, cost: 15 cents
```

3. **Verify in Firestore:**
   - Your transaction now shows `usedSubscription: true`

---

## 🔍 What to Check in Firebase Console

### Firestore Collections:
https://console.firebase.google.com/project/thrift-882cb/firestore

1. **`transactions`** - Should have your test purchase
   ```json
   {
     "transactionId": "2000001...",
     "userId": "your_firebase_uid",
     "price": 79.00,
     "usedSubscription": true,
     "playTimeSeconds": 120,
     ...
   }
   ```

2. **`user_consumption`** - Should have your usage events
   ```json
   {
     "userId": "...",
     "lastSyncAt": "...",
     "events": [...]
   }
   ```

### Function Logs:
https://console.firebase.google.com/project/thrift-882cb/functions

Look for:
- ✅ `recordTransaction` logs showing transaction saves
- ✅ `syncConsumptionData` logs showing event syncs
- ✅ `appleConsumptionWebhook` logs (when you run test script)

---

## ✅ Success Criteria

Your system is working if:

1. ✅ Test script returns 200 OK
2. ✅ Transactions appear in Firestore after purchase
3. ✅ Play time increases with app usage
4. ✅ Subscription marked as "used" after premium feature
5. ✅ No errors in Firebase function logs

---

## 🎉 You're All Set!

Once all tests pass, your system is:
- ✅ **Recording all purchases**
- ✅ **Tracking user engagement**
- ✅ **Monitoring feature usage**
- ✅ **Ready to defend chargebacks**

### What Happens on Real Chargeback:

```
User initiates chargeback
         ↓
Apple sends CONSUMPTION_REQUEST to your webhook
         ↓
Your system responds automatically with:
  • Transaction details
  • Play time
  • Premium features used
  • API costs incurred
         ↓
Apple considers this data in their decision
         ↓
Higher chance of chargeback denial! 🛡️
```

---

## 🐛 Troubleshooting

### "Transaction not found in Firestore"
- Make sure purchase completed successfully
- Check function logs for errors
- Verify internet connection during purchase

### "Play time not tracking"
- Ensure app is running from Xcode
- Check for session start/end logs
- Verify app lifecycle handlers

### "Webhook test fails"
- Confirm function is deployed: `firebase deploy --only functions`
- Check Firebase Console for function errors
- Verify webhook URL in App Store Connect

---

## 📞 Need Help?

Check the detailed documentation:
- `TEST-CONSUMPTION-TRACKING.md` - Complete testing guide
- `CONSUMPTION-TRACKING-COMPLETE.md` - Full implementation details
- `Apple-Consumption-Tracking-Setup.md` - Original setup guide

---

**🎯 Your consumption tracking is production-ready!**

