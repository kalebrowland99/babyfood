# 🔍 Where to Check Refund Requests

## ✅ Updated! Your webhook now logs everything to Firestore

---

## 📊 **Primary Check: Firestore Collection**

### **URL:** 
https://console.firebase.google.com/project/thrift-882cb/firestore

### **Collection:** `consumption_requests`

**What You'll See:**

When a refund request comes in, a document will be created:

```json
{
  "notificationType": "CONSUMPTION_REQUEST",
  "notificationUUID": "db9538cc-5970-401c-9c7f-...",
  "transactionId": "14",
  "originalTransactionId": "14",
  "productId": "com.thrifty.thrifty.unlimited.monthly",
  "requestReason": "UNINTENDED_PURCHASE",
  "requestedAt": "2025-10-25T20:30:00Z",
  "environment": "Sandbox",
  "status": "completed",
  
  // Response data we sent to Apple
  "responseData": {
    "accountTenure": 3,
    "consumptionStatus": 2,
    "playTime": 3,
    "lifetimeDollarsPurchased": 2,
    "refundPreference": 2,
    "customData": {
      "totalAPICallsMade": 3,
      "totalCostCents": 21,
      "featuresUsed": ["price_analysis"],
      "analysesCreated": 1
    }
  },
  
  "responseSentAt": "2025-10-25T20:30:01Z",
  "appleResponseStatus": 200,
  "error": null
}
```

---

## 🔍 **Secondary Check: Firebase Function Logs**

### **URL:**
https://console.firebase.google.com/project/thrift-882cb/functions

Click on `appleConsumptionWebhook` → View Logs

**What to Look For:**

```
📡 CONSUMPTION_REQUEST received for transaction: 14
📋 Reason: UNINTENDED_PURCHASE
✅ Consumption request logged to Firestore: abc123xyz
📊 Aggregated usage data for user XUZJooNliSXd890EVWnSrRCjvph2:
💎 Custom usage data included:
   - Total API Calls: 3
   - Total Cost: $0.21
   - Features Used: price_analysis, map_interaction
   - Analyses Created: 1
🔄 Sending consumption data to Apple API
✅ Successfully sent consumption data to Apple
✅ Consumption request completed and logged
```

---

## 🧪 **Testing: How to Trigger a Test Refund**

### **Option 1: RevenueCat Dashboard**

1. Go to: https://app.revenuecat.com
2. Navigate to your project
3. Find test user in **Customers**
4. Look for "Test Refund" or "Debug" option
5. Click it

### **Option 2: Apple Sandbox**

1. Go to: https://appstoreconnect.apple.com
2. Navigate to: **Users and Access** → **Sandbox Testers**
3. Find your test account
4. Request a refund through the App Store app on device

### **Option 3: Manual Webhook Test**

You can manually trigger your webhook with a test payload:

```bash
curl -X POST https://us-central1-thrift-882cb.cloudfunctions.net/appleConsumptionWebhook \
  -H "Content-Type: application/json" \
  -d '{"signedPayload": "test_payload"}'
```

---

## 📋 **Refund Request Reasons**

Apple sends one of these reasons:

| Reason | What it Means |
|--------|---------------|
| `UNINTENDED_PURCHASE` | User claims accidental purchase |
| `DISSATISFACTION_WITH_PURCHASE` | User unhappy with product |
| `LEGAL` | Legal reasons |
| `OTHER` | Other reasons |

---

## ✅ **What Should Happen:**

### **When Test Refund Clicked:**

1. **Apple sends notification** to your webhook
   ```
   POST https://us-central1-thrift-882cb.cloudfunctions.net/appleConsumptionWebhook
   ```

2. **Your webhook receives it:**
   - Logs to Firebase Functions console
   - Creates document in `consumption_requests` collection

3. **Webhook processes:**
   - Looks up transaction in `transactions` collection
   - Aggregates usage data from `user_consumption` events
   - Calculates all Apple-required fields

4. **Webhook responds to Apple:**
   - Sends complete consumption data
   - Updates Firestore document with response

---

## 🐛 **Troubleshooting: "I don't see anything"**

### **Check 1: Is webhook configured in App Store Connect?**

Go to: https://appstoreconnect.apple.com
- Your App → App Information → Server Notifications
- Verify URL: `https://us-central1-thrift-882cb.cloudfunctions.net/appleConsumptionWebhook`

### **Check 2: Look at function logs first**

Even if Firestore is empty, function logs will show if webhook was called:
https://console.firebase.google.com/project/thrift-882cb/functions

Look for:
```
📡 CONSUMPTION_REQUEST received
```

If you see this → webhook is working, check Firestore permissions
If you DON'T see this → webhook isn't receiving requests

### **Check 3: Environment**

Test refunds usually come from:
- **Sandbox environment** (testing)
- **Production environment** (real users)

Make sure you're testing with sandbox and the webhook is configured for sandbox in App Store Connect.

### **Check 4: Transaction exists**

The webhook needs to find the transaction in Firestore:
- Check `transactions` collection
- Make sure transaction ID matches
- For transaction `14`, you should have a document with that ID

---

## 📊 **Real-World Timeline:**

### **Sandbox Testing:**
```
Test refund clicked → Immediate webhook call → See in logs/Firestore instantly
```

### **Production (Real User):**
```
User requests refund → Apple reviews (0-48 hours) → 
Apple sends CONSUMPTION_REQUEST → Your webhook responds → 
Apple makes decision (within 12 hours)
```

---

## 🎯 **Quick Checklist:**

When testing refunds, verify:

- [ ] Firestore `consumption_requests` collection exists
- [ ] Function logs show webhook was called
- [ ] Document created in `consumption_requests`
- [ ] Document status is "completed"
- [ ] `responseData` field has consumption info
- [ ] `appleResponseStatus` is 200
- [ ] No errors in function logs

---

## 📞 **Still Not Seeing Requests?**

1. **Check webhook URL in App Store Connect**
   - Must be exactly: `https://us-central1-thrift-882cb.cloudfunctions.net/appleConsumptionWebhook`
   - Set for BOTH production AND sandbox

2. **Check function logs for ANY activity**
   - If completely silent → webhook not receiving requests
   - If has errors → check error messages

3. **Verify transaction exists**
   - Transaction ID must exist in `transactions` collection
   - User must have made a purchase first

4. **Test with known transaction**
   - You have transaction `14` in Firestore
   - Try requesting refund for that specific purchase

---

## ✅ **Success Looks Like:**

### **Firestore:**
New document in `consumption_requests` collection ✅

### **Function Logs:**
```
📡 CONSUMPTION_REQUEST received for transaction: 14
✅ Consumption request logged to Firestore
✅ Successfully sent consumption data to Apple
```

### **Result:**
Apple has your comprehensive usage data to make refund decision! 🎯

---

**Your webhook is now deployed and ready to log all consumption requests!** 🚀

