# Production Setup Guide - Switch from Test to Live Keys

## Overview
This guide will help you switch from test/sandbox keys to live production keys for your Thrifty app.

---

## 1. Apple StoreKit - Switch from SANDBOX to PRODUCTION

### Current Status: SANDBOX ❌
### Target: PRODUCTION ✅

**Steps:**

```bash
cd /Users/elianasilva/Desktop/thrift/functions

# Set Apple environment to PRODUCTION
firebase functions:config:set apple.environment="PRODUCTION"

# Deploy the changes
firebase deploy --only functions
```

**What this does:**
- Changes Apple App Store Server API from sandbox to production
- Enables real transaction verification
- Required for live app in production

---

## 2. Stripe - Add Live Secret Key

### Current Status: NOT CONFIGURED ❌
### Target: LIVE KEY CONFIGURED ✅

**Steps:**

### A. Get your Stripe Live Secret Key
1. Go to https://dashboard.stripe.com
2. Switch to **Live mode** (toggle in top right)
3. Go to **Developers → API Keys**
4. Copy your **Secret key** (starts with `sk_live_...`)

### B. Add the key to Firebase Secrets
```bash
cd /Users/elianasilva/Desktop/thrift/functions

# Set the Stripe secret key (you'll be prompted to paste it)
firebase functions:secrets:set STRIPE_SECRET_KEY

# When prompted, paste your live key: sk_live_XXXXXXXXX
```

### C. Update function to use the secret
The function code already references `process.env.STRIPE_SECRET_KEY`, so no code changes needed.

### D. Deploy
```bash
firebase deploy --only functions:stripeWebhook,functions:getStripeCheckoutUrl
```

---

## 3. Update Stripe Checkout URL in Firestore

### Current Status: Test checkout URL
### Target: Live checkout URL

**Steps:**

1. Go to https://dashboard.stripe.com (ensure you're in **Live mode**)
2. Go to **Products** → Select your product
3. Create a **Payment Link** for your live product
4. Copy the checkout URL (should look like: `https://buy.stripe.com/live_XXXXXXXXX`)

5. Update Firestore:
```
Collection: app_config
Document: paywall_config
Field: stripecheckouturl
Value: https://buy.stripe.com/live_XXXXXXXXX
```

Or via Firebase Console:
- Navigate to Firestore Database
- Go to `app_config` → `paywall_config`
- Edit field `stripecheckouturl`
- Update with your live Stripe checkout URL

---

## 4. Apple App Store Connect - Production Setup

### Ensure these are configured for PRODUCTION:

1. **In-App Purchase Products** must be approved:
   - `com.thrifty.thrifty.unlimited.yearly149` - Yearly subscription
   - `com.thrifty.thrifty.unlimited.yearly.winback79` - Winback offer
   - `com.thrifty.thrifty.unlimited.monthly` - Monthly subscription

2. **App Store Server Notifications**:
   - URL: Your production webhook URL
   - Enable all notification types

3. **Consumption Information**:
   - Ensure your app is approved for consumption tracking
   - Verify webhook is receiving PRODUCTION notifications

---

## 5. Verify All Secrets are Set

Run this to check what secrets are configured:

```bash
cd /Users/elianasilva/Desktop/thrift/functions

# Check Apple secrets
firebase functions:secrets:access APPLE_KEY_ID
firebase functions:secrets:access APPLE_ISSUER_ID
firebase functions:secrets:access APPLE_PRIVATE_KEY

# Check Stripe secret
firebase functions:secrets:access STRIPE_SECRET_KEY

# Check RevenueCat (if using)
firebase functions:secrets:access REVENUECAT_API_KEY
```

If any are missing, set them:
```bash
firebase functions:secrets:set SECRET_NAME
```

---

## 6. Update Firebase Function Secrets (Apple Keys)

### Verify Apple Keys are for PRODUCTION:

Your Apple API keys (Key ID, Issuer ID, Private Key) should work for both sandbox AND production. However, verify:

1. Go to https://appstoreconnect.apple.com
2. Navigate to **Users and Access → Integrations → App Store Connect API**
3. Verify your API key has the correct permissions:
   - **App Manager** or **Admin** role required

If you need to update them:
```bash
firebase functions:secrets:set APPLE_KEY_ID
firebase functions:secrets:set APPLE_ISSUER_ID
firebase functions:secrets:set APPLE_PRIVATE_KEY
```

---

## 7. Deploy All Changes

After updating all configurations:

```bash
cd /Users/elianasilva/Desktop/thrift/functions

# Deploy all functions with updated secrets
firebase deploy --only functions
```

---

## 8. Test in Production

### Verification Checklist:

- [ ] Apple environment is set to PRODUCTION
- [ ] Stripe live secret key is configured
- [ ] Stripe checkout URL points to live product
- [ ] All Apple secrets are configured
- [ ] Functions are deployed successfully
- [ ] Test a real purchase with a real payment method
- [ ] Verify webhook receives PRODUCTION notifications
- [ ] Check Firestore for transaction data
- [ ] Verify consumption requests are sent to Apple production servers

---

## 9. Monitoring

After switching to production:

1. **Monitor Firebase Functions logs:**
```bash
firebase functions:log
```

2. **Check for errors:**
   - Look for "PRODUCTION" in logs (not "SANDBOX")
   - Verify Stripe webhooks are working
   - Verify Apple webhook notifications

3. **Monitor Stripe Dashboard:**
   - Check for incoming payments
   - Verify webhook events are received

4. **Monitor Apple App Store Connect:**
   - Check for subscription events
   - Verify consumption requests

---

## Quick Command Reference

```bash
# Switch Apple to PRODUCTION
firebase functions:config:set apple.environment="PRODUCTION"

# Set Stripe live key
firebase functions:secrets:set STRIPE_SECRET_KEY

# Deploy all functions
firebase deploy --only functions

# View logs
firebase functions:log --only stripeWebhook,appleConsumptionWebhook

# Check current config
firebase functions:config:get
```

---

## Rollback (if needed)

If you need to revert to test mode:

```bash
# Switch back to SANDBOX
firebase functions:config:set apple.environment="SANDBOX"

# Deploy
firebase deploy --only functions
```

⚠️ **Note:** Keep your test Stripe key handy in case you need to switch back for testing.

---

## Important Notes

1. **Test thoroughly** before going live with real customers
2. **Keep backups** of all your keys in a secure location (1Password, etc.)
3. **Never commit** live keys to git
4. **Monitor closely** for the first few days after switching to production
5. **Have a rollback plan** ready in case issues arise

---

## Support

If you encounter issues:
- Check Firebase Functions logs: `firebase functions:log`
- Check Stripe webhook logs in Stripe Dashboard
- Check App Store Connect for transaction issues
- Verify all secrets are properly configured

---

**Last Updated:** November 6, 2025
**Status:** Ready for Production Switch ✅

