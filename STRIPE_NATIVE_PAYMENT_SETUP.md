# 🎯 Native Stripe Payment Sheet Setup Guide

## Overview

Your app now supports **true in-app Stripe payments** using the native Stripe iOS SDK. When `usestripesheet` is enabled, users complete the entire payment flow within the app—no external browser redirect needed!

## ✅ What's Been Implemented

### 1. **Stripe iOS SDK Integration**
- ✅ Added `stripe-ios` package (v23.0.0+) to Xcode project
- ✅ Integrated StripePaymentSheet for native card input
- ✅ Full support for 3-day free trial subscriptions

### 2. **Firebase Cloud Function**
- ✅ New function: `createStripePaymentSheet`
- ✅ Creates Stripe Customer (or retrieves existing)
- ✅ Creates subscription with trial period
- ✅ Generates ephemeral keys for secure client-side payment
- ✅ Returns PaymentSheet configuration

### 3. **Swift Payment Service**
- ✅ `StripePaymentService.swift` - Handles native payment flow
- ✅ Integrates with existing auth system (requires email)
- ✅ Supports both main subscription and winback offers
- ✅ Test and production mode support

### 4. **ContentView Integration**
- ✅ Main subscription button updated
- ✅ Winback offer button updated
- ✅ Automatic mode switching based on `usestripesheet` flag
- ✅ Error handling and loading states

---

## 🔧 Firebase Configuration Required

### Step 1: Set Up Firebase Secrets

Run these commands to configure Stripe API keys:

```bash
# Test mode keys
firebase functions:secrets:set STRIPE_SECRET_KEY_TEST
# Enter: sk_test_YOUR_TEST_SECRET_KEY

firebase functions:secrets:set STRIPE_WEBHOOK_SECRET_TEST
# Enter: whsec_YOUR_TEST_WEBHOOK_SECRET

# Production keys
firebase functions:secrets:set STRIPE_SECRET_KEY_PROD
# Enter: sk_live_YOUR_LIVE_SECRET_KEY

firebase functions:secrets:set STRIPE_WEBHOOK_SECRET_PROD
# Enter: whsec_YOUR_PROD_WEBHOOK_SECRET
```

**Where to find these:**
- Stripe Dashboard → Developers → API Keys
- Test keys start with `sk_test_`
- Live keys start with `sk_live_`
- Webhook secrets from Developers → Webhooks

### Step 2: Deploy Firebase Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

This will deploy:
- `createStripePaymentSheet` - New native payment function
- `getStripeCheckoutUrl` - Existing external redirect function (legacy)
- `stripeWebhook` - Handles subscription events

### Step 3: Configure Firestore

Create/update document: `app_config/paywall_config`

```javascript
{
  // Core Settings
  "hardpaywall": true,              // Force paywall
  "stripepaywall": true,             // Use Stripe (not Apple IAP)
  "usestripesheet": true,            // ⭐ Enable native in-app payments
  "useproductionmode": false,        // Start with test mode
  
  // URLs (used when usestripesheet = false)
  "stripecheckouturl": "https://us-central1-thrift-882cb.cloudfunctions.net/getStripeCheckoutUrl",
  "stripecheckouturltest": "https://us-central1-thrift-882cb.cloudfunctions.net/getStripeCheckoutUrl",
  "winbackcheckouturl": "https://us-central1-thrift-882cb.cloudfunctions.net/getStripeCheckoutUrl?isWinback=true",
  "winbackcheckouturltest": "https://us-central1-thrift-882cb.cloudfunctions.net/getStripeCheckoutUrl?isWinback=true",
  
  // UI Customization
  "stripebuttontext": "Try for $0.00",
  "stripedisclaimertext": "Free for 3 days, then $79.99 per year after.",
  "winbackdisclaimertext": "Free for 3 days, then $79.00 per year after.",
  "termsurl": "https://thrifty.com/terms"
}
```

### Step 4: Update Firestore Security Rules

Ensure `firestore.rules` allows reading app config:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow reading app config
    match /app_config/{document=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

---

## 🎯 How It Works

### Flow Comparison

| Feature | External Redirect (Old) | Native Payment Sheet (New) |
|---------|------------------------|----------------------------|
| User leaves app | ✅ Yes (opens browser) | ❌ No (stays in app) |
| Payment UI | Stripe hosted page | Native iOS sheet |
| Apple style | ❌ Custom web page | ✅ Native iOS design |
| User experience | Disruptive | Seamless |
| Conversion rate | Lower | Higher (expected) |

### Native Payment Flow

1. User taps "Try for $0.00" button
2. App calls `createStripePaymentSheet` Firebase function
3. Function creates/retrieves Stripe Customer
4. Function creates subscription with 3-day trial
5. Function returns PaymentSheet configuration
6. App presents native payment sheet
7. User enters card details in-app
8. Payment confirmed, subscription activated
9. Webhook updates Firestore subscription status

---

## 🧪 Testing Guide

### Test Mode (Recommended First)

1. **Configure Test Mode:**
```javascript
{
  "usestripesheet": true,
  "useproductionmode": false
}
```

2. **Use Stripe Test Cards:**
   - Success: `4242 4242 4242 4242`
   - Decline: `4000 0000 0000 0002`
   - Requires 3D Secure: `4000 0027 6000 3184`
   - Any future expiry date (e.g., 12/34)
   - Any 3-digit CVC

3. **Test Flow:**
   - Log in with a test account
   - Navigate to paywall
   - Tap subscription button
   - Native payment sheet should appear
   - Enter test card details
   - Confirm payment
   - Verify subscription activated

4. **Check Logs:**
```bash
firebase functions:log --only createStripePaymentSheet
```

### Production Mode

Once testing is complete:

```javascript
{
  "usestripesheet": true,
  "useproductionmode": true
}
```

**Important:** Ensure production Stripe keys are configured!

---

## 🔄 Switching Modes

You can switch between native payment sheet and external redirect at any time:

### Native In-App Payment (Recommended)
```javascript
{
  "usestripesheet": true
}
```
- ✅ Payment happens in-app
- ✅ Better user experience
- ✅ Higher conversion expected
- ✅ Native iOS design

### External Browser Redirect (Legacy)
```javascript
{
  "usestripesheet": false
}
```
- Opens Safari/browser
- Payment on Stripe's website
- Returns to app via deep link
- Previous implementation

---

## 📊 Price IDs Configured

The system uses these Stripe price IDs:

**Production:**
- Main subscription: `price_1SPpOGEAO5iISw7Sr6ytdoYP` ($79.99/year)
- Winback offer: `price_1SQL9NEAO5iISw7Sr650SppU` ($79.99/year)

**Test:**
- Test subscription: `price_1SPpmQEAO5iISw7SKWdV84yy`

All include a 3-day free trial period.

---

## ⚠️ Important Notes

1. **User Must Be Logged In**
   - Native payment requires user email
   - App will show error if user not authenticated

2. **Stripe Customer Management**
   - Function automatically creates Stripe customers
   - Associates customers with Firebase user IDs
   - Retrieves existing customers by email

3. **Webhook Handling**
   - Existing `stripeWebhook` function handles events
   - Updates Firestore subscription status
   - Tracks Meta conversions
   - No changes needed to webhook logic

4. **Deep Links**
   - Return URL: `thriftyapp://stripe-return`
   - Ensure URL scheme is configured in Xcode

5. **Trial Period**
   - 3 days free, hardcoded
   - To change, edit both:
     - `functions/index.js` line 1611
     - Firebase function parameter

---

## 🐛 Debugging

### Check Payment Sheet Creation

Look for console logs:
```
📱 Creating native Stripe PaymentSheet...
📧 Email: user@example.com
🔧 Mode: TEST
✅ PaymentSheet configuration received
```

### Check Function Logs

```bash
# View all function logs
firebase functions:log

# View specific function
firebase functions:log --only createStripePaymentSheet

# Real-time logs
firebase functions:log --follow
```

### Common Issues

**"User email required"**
- User not logged in
- Ensure AuthenticationManager has valid email

**"Invalid function URL"**
- Check Firebase project ID in URL
- Default: `https://us-central1-thrift-882cb.cloudfunctions.net/`

**Payment sheet not appearing**
- Check `usestripesheet` is `true` in Firestore
- Verify app reloaded config
- Check console for errors

**Subscription not activating**
- Check webhook is receiving events
- Verify webhook secret matches
- Check Firestore for subscription document

---

## 📈 Recommended Rollout

1. **Test with Test Mode** ✅
   - `useproductionmode: false`
   - Verify payment flow works
   - Test with Stripe test cards

2. **Limited Production Test**
   - `useproductionmode: true`
   - Test with real card (your own)
   - Verify subscription activates

3. **A/B Test** (Optional)
   - Split users between native and external
   - Track conversion rates
   - Choose winner

4. **Full Rollout**
   - Enable `usestripesheet: true` for all users
   - Monitor logs and conversion rates

---

## 🎨 Customization

### Payment Sheet Appearance

Edit `StripePaymentService.swift` line 98-104:

```swift
var appearance = PaymentSheet.Appearance()
appearance.cornerRadius = 12
appearance.primaryButton.backgroundColor = UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)
configuration.appearance = appearance
```

### Merchant Display Name

Edit `StripePaymentService.swift` line 95:

```swift
configuration.merchantDisplayName = "Thrifty: Scan & Flip Items"
```

---

## 📝 Quick Start Checklist

- [ ] Set up Firebase secrets (4 secrets)
- [ ] Deploy Firebase functions
- [ ] Create Firestore `app_config/paywall_config` document
- [ ] Set `usestripesheet: true` and `useproductionmode: false`
- [ ] Deploy Firestore rules
- [ ] Test with test cards in app
- [ ] Verify subscription activates
- [ ] Check webhook receives events
- [ ] Test production mode with real card
- [ ] Enable for all users

---

## 🚀 Benefits

✅ **Better User Experience** - No leaving the app  
✅ **Higher Conversion** - Native feels more trustworthy  
✅ **Faster Checkout** - Fewer steps  
✅ **Apple-Style UI** - Familiar payment interface  
✅ **Seamless Flow** - No browser redirect interruption  
✅ **Immediate Feedback** - Instant success/error handling  

---

**Created**: November 12, 2025  
**Last Updated**: November 12, 2025  
**Version**: 1.0

Need help? Check Firebase function logs or Xcode console for detailed error messages.

