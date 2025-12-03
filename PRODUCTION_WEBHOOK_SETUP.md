# 🚀 Stripe Webhook Setup (Test & Production)

## Overview

Configure Stripe webhooks for both **TEST** and **PRODUCTION** modes. The app will automatically use the correct webhook based on your Firebase Remote Config `useproductionmode` setting.

---

## ⚠️ Important Notes

- You need to configure webhooks in **BOTH** Test and Live modes
- The webhook URL is the same for both modes
- Each mode uses a different signing secret
- The webhook function auto-detects which mode based on the event
- Both test and live webhooks can coexist

---

## 📋 Step-by-Step Setup

### Step 1A: Configure TEST Webhook in Stripe Dashboard

1. **Go to Stripe Dashboard** (TEST MODE):
   - https://dashboard.stripe.com/test/webhooks
   - **Make sure you're in TEST mode** (toggle in top right should say "TEST")

2. **Click "+ Add endpoint"**

3. **Configure the endpoint:**
   ```
   Endpoint URL: https://stripewebhook-xhxqzuqe3q-uc.a.run.app
   ```
   
   OR if that doesn't work, use:
   ```
   https://us-central1-thrift-882cb.cloudfunctions.net/stripeWebhook
   ```

4. **Description:** 
   ```
   Thrifty Test Webhook
   ```

5. **Events to send:** Click "Select events" and choose:
   - ✅ `checkout.session.completed`
   - ✅ `customer.subscription.created`
   - ✅ `customer.subscription.updated`
   - ✅ `customer.subscription.deleted`
   - ✅ `invoice.payment_succeeded`
   - ✅ `invoice.payment_failed`

6. **Click "Add endpoint"**

7. **Copy the Signing Secret:**
   - After creating, Stripe shows a signing secret like: `whsec_...`
   - **Verify it matches:** `whsec_duFFFRMfaFqSBMcNaOMpZ8oU9cuYCJaU`
   - If different, run:
     ```bash
     printf "YOUR_NEW_SECRET" | firebase functions:secrets:set STRIPE_WEBHOOK_SECRET_TEST
     firebase deploy --only functions:stripeWebhook
     ```

8. **Test the webhook:**
   - Click "Send test webhook" button
   - Send a `checkout.session.completed` event
   - Check Firebase logs for success

---

### Step 1B: Configure LIVE Webhook in Stripe Dashboard

1. **Go to Stripe Dashboard** (LIVE MODE):
   - https://dashboard.stripe.com/webhooks
   - **Make sure you're in LIVE mode** (toggle in top right should say "LIVE")

2. **Click "+ Add endpoint"**

3. **Configure the endpoint:**
   ```
   Endpoint URL: https://stripewebhook-xhxqzuqe3q-uc.a.run.app
   ```
   
   OR if that doesn't work, use:
   ```
   https://us-central1-thrift-882cb.cloudfunctions.net/stripeWebhook
   ```

4. **Description:** 
   ```
   Thrifty Production Webhook
   ```

5. **Events to send:** Click "Select events" and choose:
   - ✅ `checkout.session.completed`
   - ✅ `customer.subscription.created`
   - ✅ `customer.subscription.updated`
   - ✅ `customer.subscription.deleted`
   - ✅ `invoice.payment_succeeded`
   - ✅ `invoice.payment_failed`

6. **Click "Add endpoint"**

7. **Copy the Signing Secret:**
   - After creating, Stripe shows a signing secret like: `whsec_...`
   - **Save this secret** - you'll need it in Step 2
   
8. **Test the webhook:**
   - Click "Send test webhook" button
   - Send a `checkout.session.completed` event
   - Should see "Succeeded" (or may fail if secret not configured yet - that's OK)

---

### Step 2: Configure Webhook Secrets in Firebase

**For TEST webhook:**

```bash
cd /Users/elianasilva/Desktop/thrift/functions

# Set test webhook secret (if different from what's already stored)
printf "whsec_YOUR_TEST_SECRET" | firebase functions:secrets:set STRIPE_WEBHOOK_SECRET_TEST
```

**For LIVE webhook:**

```bash
# Set production webhook secret
printf "whsec_YOUR_LIVE_SECRET" | firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

---

### Step 3: Deploy Functions with Webhook Secrets

```bash
firebase deploy --only functions:stripeWebhook
```

This will deploy the webhook function with access to both test and production signing secrets.

---

### Step 4: Test Both Webhooks

**Test Mode Webhook:**

1. **Go to Stripe Dashboard** (TEST MODE):
   - https://dashboard.stripe.com/test/webhooks

2. **Click on your test webhook endpoint**

3. **Click "Send test webhook"**

4. **Select event:** `checkout.session.completed`

5. **Click "Send test webhook"**

6. **Check the response:**
   - Should show "Succeeded" with 200 status
   - If it fails, check Firebase logs:
     ```bash
     firebase functions:log --only stripeWebhook
     ```

**Production Mode Webhook:**

1. **Go to Stripe Dashboard** (LIVE MODE):
   - https://dashboard.stripe.com/webhooks

2. **Follow same steps as above for the production webhook**

---

### Step 5: Verify End-to-End Flow

**Test Mode (useproductionmode: false):**

1. In Firebase Console, set Remote Config:
   - `useproductionmode` = `false`

2. In your app, attempt a Stripe checkout

3. Complete test purchase with test card: `4242 4242 4242 4242`

4. After checkout, check:
   - Webhook should fire automatically
   - User should get premium access
   - Firestore should have subscription data

**Production Mode (useproductionmode: true):**

1. In Firebase Console, set Remote Config:
   - `useproductionmode` = `true`

2. **WARNING:** This will use REAL payment cards!

3. Same flow as test, but with real card

---

### Step 6: Monitor Webhooks

**From Stripe Dashboard:**

1. **Send a real test event** from Stripe Dashboard:
   - Go to your webhook in Stripe Dashboard
   - Click "Send test webhook"
   - Select `checkout.session.completed`
   - Click "Send test webhook"

2. **Check Firebase logs:**
   ```bash
   firebase functions:log --only stripeWebhook
   ```

3. **Look for:**
   - ✅ "Webhook signature verified" (means it's working!)
   - ❌ "Webhook signature verification failed" (secret is wrong)
   - ⚠️ "Webhook signature verification skipped" (secret not set)

---

## 🔍 Verification Checklist

After setup, verify:

**Test Mode:**
- [ ] Webhook endpoint exists in Stripe Dashboard (TEST mode)
- [ ] All 6 events are selected
- [ ] Test webhook signing secret is set in Firebase (`STRIPE_WEBHOOK_SECRET_TEST`)
- [ ] Test webhook sends successfully from Stripe dashboard
- [ ] Firebase logs show "Webhook signature verified" with "TEST" mode

**Production Mode:**
- [ ] Webhook endpoint exists in Stripe Dashboard (LIVE mode)
- [ ] All 6 events are selected
- [ ] Production webhook signing secret is set in Firebase (`STRIPE_WEBHOOK_SECRET`)
- [ ] Test webhook sends successfully from Stripe dashboard
- [ ] Firebase logs show "Webhook signature verified" with "PRODUCTION" mode

**General:**
- [ ] Function is deployed with access to both secrets
- [ ] Remote Config `useproductionmode` controls which mode is used
- [ ] App creates correct checkout sessions based on mode

---

## 🔄 How Automatic Mode Switching Works

Your setup now includes:

1. **Two Stripe API Keys:**
   - `STRIPE_SECRET_KEY_TEST` → Test mode
   - `STRIPE_SECRET_KEY_PROD` → Production mode

2. **Two Webhook Secrets:**
   - `STRIPE_WEBHOOK_SECRET_TEST` → Test webhooks
   - `STRIPE_WEBHOOK_SECRET` → Production webhooks

3. **Automatic Detection:**
   - Firebase function checks `useProductionMode` parameter from app
   - Webhook function detects mode from Stripe event's `livemode` field
   - Correct keys/secrets are used automatically

4. **Control via Remote Config:**
   ```
   useproductionmode: false → Uses test keys/webhooks
   useproductionmode: true  → Uses production keys/webhooks
   ```

**No code changes needed to switch between test and production!** Just toggle Remote Config.

---

## 📊 What Gets Stored

When webhooks fire, the system stores:

**Firestore Collections:**

1. **`stripe_customers/{customerId}`**
   - Customer ID
   - Subscription ID
   - Status
   - Trial end date
   - Metadata

2. **`users/{userId}`** (if user ID provided)
   - Stripe Customer ID
   - isPremium: true
   - subscriptionStatus
   - subscriptionId

---

## 🔄 Webhook Events Handled

| Event | What It Does |
|-------|--------------|
| `checkout.session.completed` | Creates subscription record, marks user as premium |
| `customer.subscription.created` | Logs new subscription |
| `customer.subscription.updated` | Updates subscription status (renewals, changes) |
| `customer.subscription.deleted` | Marks user as non-premium, logs cancellation |
| `invoice.payment_succeeded` | Logs successful payments |
| `invoice.payment_failed` | Logs failed payments, updates status |

---

## 🐛 Troubleshooting

### Issue: "Webhook signature verification failed"

**Solution:**
1. Double-check you copied the correct secret from Stripe
2. Make sure you're using the LIVE mode secret (not test)
3. Redeploy the function: `firebase deploy --only functions:stripeWebhook`

### Issue: "Webhook signature verification skipped"

**Solution:**
The secret isn't set. Run:
```bash
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

### Issue: Webhook not receiving events

**Solution:**
1. Check the endpoint URL is correct
2. Verify the webhook is in LIVE mode (not test)
3. Send a test event from Stripe Dashboard
4. Check Firebase logs: `firebase functions:log --only stripeWebhook`

---

## 🔐 Security Best Practices

✅ **Always verify webhook signatures** in production  
✅ **Use Firebase Secrets** (not environment variables) for signing secret  
✅ **Never commit** webhook secrets to git  
✅ **Use separate webhooks** for test and live modes  
✅ **Monitor webhook failures** in Stripe Dashboard  

---

## 📝 Quick Command Reference

```bash
# Set webhook secret
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET

# Deploy webhook function
firebase deploy --only functions:stripeWebhook

# View webhook logs
firebase functions:log --only stripeWebhook

# Check if secret is set
firebase functions:secrets:access STRIPE_WEBHOOK_SECRET
```

---

## 🎯 After Setup

Once webhooks are working:

1. **Test a real purchase** with live payment
2. **Verify data** appears in Firestore
3. **Check user** is marked as premium
4. **Monitor logs** for first few days
5. **Set up alerts** in Stripe for webhook failures

---

## 📚 Additional Resources

- [Stripe Webhooks Documentation](https://stripe.com/docs/webhooks)
- [Firebase Secret Manager](https://firebase.google.com/docs/functions/config-env#secret-manager)
- Stripe Dashboard: https://dashboard.stripe.com/webhooks

---

**Created:** November 6, 2025  
**Status:** Ready to configure  
**Last Updated:** November 6, 2025

