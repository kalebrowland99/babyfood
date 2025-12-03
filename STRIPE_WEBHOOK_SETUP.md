# 🔒 Stripe Webhook Setup Guide

## ✅ What's Been Done:

1. ✅ Firebase webhook function deployed
2. ✅ iOS app updated to read from Firestore
3. ✅ Checkout session links to user ID
4. ✅ Deep link + webhook architecture ready

---

## 🎯 What You Need To Do (15 minutes):

### **Step 1: Add Webhook URL to Stripe** 🔗

1. Go to Stripe Dashboard → Developers → Webhooks
   OR use this link: https://dashboard.stripe.com/test/webhooks

2. Click **"+ Add endpoint"**

3. **Endpoint URL:** 
   ```
   https://us-central1-thrift-882cb.cloudfunctions.net/stripeWebhook
   ```

4. **Description:** `Thrifty Subscription Webhook`

5. **Events to send:** Click "Select events" and choose these:
   - ✅ `checkout.session.completed`
   - ✅ `customer.subscription.created`
   - ✅ `customer.subscription.updated`
   - ✅ `customer.subscription.deleted`
   - ✅ `invoice.payment_succeeded`
   - ✅ `invoice.payment_failed`

6. Click **"Add endpoint"**

---

### **Step 2: Get Webhook Signing Secret** 🔑

1. After creating the webhook, you'll see your endpoint listed

2. Click on the endpoint you just created

3. Find the **"Signing secret"** section

4. Click **"Reveal"** to see the secret

5. It looks like: `whsec_XXXXXXXXXXXXXXXXXXXXXXX`

6. **Copy this secret!**

---

### **Step 3: Update Firebase Environment** 🔧

Run this command in your terminal (replace with your actual secret):

```bash
cd /Users/elianasilva/Desktop/thrift/functions
```

Then edit `.env` file and replace:
```bash
STRIPE_WEBHOOK_SECRET=whsec_YOUR_WEBHOOK_SECRET_HERE
```

With your actual secret:
```bash
STRIPE_WEBHOOK_SECRET=whsec_abc123xyz789...
```

---

### **Step 4: Redeploy Function** 🚀

```bash
cd /Users/elianasilva/Desktop/thrift
firebase deploy --only functions:stripeWebhook
```

This updates the function with the webhook secret for signature verification.

---

### **Step 5: Add URL Scheme in Xcode** 📱

**In Xcode (should already be open):**

1. Click **"Thrifty"** project (blue icon)
2. Select **"Thrifty"** target
3. Click **"Info"** tab
4. Scroll to **"URL Types"**
5. Click **"+"** button
6. Add:
   - **Identifier:** `com.thrifty.thrifty`
   - **URL Schemes:** `thriftyapp`
   - **Role:** `Editor`

---

## 🧪 Test Your Webhook:

### **Option 1: Use Stripe CLI (Recommended)**
```bash
stripe listen --forward-to https://us-central1-thrift-882cb.cloudfunctions.net/stripeWebhook
stripe trigger checkout.session.completed
```

### **Option 2: Real Test Purchase**
1. Build and run the app
2. Complete a test purchase
3. Check Firebase Functions logs
4. Check Firestore `stripe_customers` collection

---

## 🔍 How to Check if It's Working:

### **1. Firebase Functions Logs:**
```bash
firebase functions:log --only stripeWebhook
```

You should see:
```
🎣 Stripe webhook received
✅ Webhook signature verified
📋 Event type: checkout.session.completed
💳 Checkout session completed: cs_test_xxx
✅ Subscription stored in Firestore
```

### **2. Firestore Collections:**

Check these collections in Firebase Console:
- `stripe_customers` - Should have customer records with subscription info
- `stripe_payments` - Should log each successful payment
- `users` - Should have `isPremium: true` and `subscriptionStatus: "active"`

---

## 🎯 Complete Architecture:

```
User Flow:
1. User clicks subscribe → App calls getStripeCheckoutUrl
2. App opens Stripe checkout in Safari
3. User completes payment
4. Stripe redirects: thriftyapp://subscription-success
5. App opens, shows success message (instant UX)
6. Stripe sends webhook to Firebase function
7. Function stores subscription in Firestore
8. App reads from Firestore (verified access)
```

**Benefits:**
- ✅ Fast UX (deep link)
- ✅ Secure (webhook verification)
- ✅ Reliable (Firestore = single source of truth)
- ✅ Handles renewals, cancellations, refunds automatically

---

## 📋 Final Checklist:

- [ ] Webhook endpoint added in Stripe Dashboard
- [ ] Webhook events selected (6 events)
- [ ] Webhook secret copied
- [ ] `.env` updated with secret
- [ ] Function redeployed
- [ ] URL scheme added in Xcode
- [ ] Firebase config updated (hardpaywall, stripepaywall)
- [ ] Test purchase completed

---

## 🆘 Troubleshooting:

**Webhook not receiving events:**
- Check endpoint URL is correct
- Check events are selected
- Check Stripe Dashboard → Webhooks → Attempts

**App not opening after payment:**
- Check URL scheme is `thriftyapp` (no typo)
- Check URL scheme added in Xcode Info.plist
- Test with: `xcrun simctl openurl booted "thriftyapp://subscription-success?session_id=test"`

**Subscription not appearing in Firestore:**
- Check Firebase Functions logs
- Check webhook secret is correct
- Check Firestore rules allow writes from Functions

---

**Once you complete these steps, everything will be production-ready!** 🚀

