# 🎯 Stripe PaymentSheet vs External Checkout - Decision Flow

## Overview

This document explains when your app uses native Stripe PaymentSheet vs external checkout, based on RemoteConfig flags.

---

## 🔧 RemoteConfig Flags

| Flag | Type | Purpose | Default |
|------|------|---------|---------|
| `hardpaywall` | boolean | Show winback on cancel | `true` |
| `stripepaywall` | boolean | Use Stripe vs Apple IAP | `false` |
| `usestripesheet` | boolean | Native sheet vs external | `false` |
| `useproductionmode` | boolean | TEST vs PROD keys | `true` |

---

## 📊 Decision Flow

### Step 1: Is user in USA?
```
storeManager.isUserInUSA()
```
- ✅ YES → Continue to Step 2
- ❌ NO → Use Apple IAP (default)

### Step 2: Is Stripe enabled?
```
remoteConfig.hardPaywall && remoteConfig.stripePaywall
```
- ✅ YES → Continue to Step 3
- ❌ NO → Use Apple IAP

### Step 3: Which Stripe method?
```
remoteConfig.useStripeSheet
```
- ✅ `true` → **Native PaymentSheet** (in-app)
- ❌ `false` → **External Checkout** (browser redirect)

---

## 🎨 Payment Methods

### Method 1: Native Stripe PaymentSheet
**Conditions:**
- `hardpaywall: true`
- `stripepaywall: true`
- `usestripesheet: true` ← **KEY FLAG**
- User in USA

**Experience:**
- Stays in app
- Native iOS payment sheet
- Apple Pay support
- Card input with Stripe UI
- Immediate subscription confirmation

**Code:**
```swift
if remoteConfig.hardPaywall && remoteConfig.stripePaywall && isUSA {
    if remoteConfig.useStripeSheet {
        // Use StripePaymentService
        let paymentSheet = try await StripePaymentService.shared.createPaymentSheet(...)
        StripePaymentService.shared.presentPaymentSheet(...)
    }
}
```

---

### Method 2: External Stripe Checkout
**Conditions:**
- `hardpaywall: true`
- `stripepaywall: true`
- `usestripesheet: false` ← **KEY FLAG**
- User in USA

**Experience:**
- Redirects to Safari
- Stripe Checkout hosted page
- Returns to app via deep link
- Requires session linking

**Code:**
```swift
if remoteConfig.hardPaywall && remoteConfig.stripePaywall && isUSA {
    if !remoteConfig.useStripeSheet {
        // Get external URL
        let checkoutUrl = try await storeManager.getStripeCheckoutUrl(...)
        UIApplication.shared.open(url)
    }
}
```

---

### Method 3: Apple In-App Purchase (IAP)
**Conditions:**
- Any of the above conditions fail
- OR user outside USA
- OR `stripepaywall: false`

**Experience:**
- Native Apple subscription UI
- StoreKit payments
- RevenueCat for backend
- No Stripe involved

**Code:**
```swift
// Default flow when Stripe conditions not met
try await product.purchase()
```

---

## 🔑 Key vs Mode Matching

### ⚠️ CRITICAL: Key/Mode Must Match!

The publishable key MUST match the mode:

| Mode | Backend Key | iOS Publishable Key | Result |
|------|-------------|---------------------|--------|
| PRODUCTION | `sk_live_...` | `pk_live_...` | ✅ Works |
| TEST | `sk_test_...` | `pk_test_...` | ✅ Works |
| PRODUCTION | `sk_live_...` | `pk_test_...` | ❌ **400 ERROR** |
| TEST | `sk_test_...` | `pk_live_...` | ❌ **400 ERROR** |

### ✅ Solution: Use Backend's Key

**Your iOS app now:**
```swift
let publishableKey = stripeResponse.publishableKey  // ← From backend
STPAPIClient.shared.publishableKey = publishableKey
```

**Backend automatically provides:**
- `pk_test_...` when `useProductionMode: false`
- `pk_live_...` when `useProductionMode: true`

---

## 🧪 Testing Scenarios

### Scenario 1: Test Native PaymentSheet
```json
{
  "hardpaywall": true,
  "stripepaywall": true,
  "usestripesheet": true,
  "useproductionmode": false
}
```
**Result:** Native sheet with TEST mode

### Scenario 2: Production Native PaymentSheet
```json
{
  "hardpaywall": true,
  "stripepaywall": true,
  "usestripesheet": true,
  "useproductionmode": true
}
```
**Result:** Native sheet with PRODUCTION mode

### Scenario 3: External Checkout
```json
{
  "hardpaywall": true,
  "stripepaywall": true,
  "usestripesheet": false,
  "useproductionmode": true
}
```
**Result:** Browser redirect to Stripe Checkout

### Scenario 4: Apple IAP
```json
{
  "stripepaywall": false
}
```
**Result:** Native Apple IAP (ignores other flags)

---

## 📱 USA Detection

```swift
func isUserInUSA() -> Bool {
    let countryCode = Locale.current.region?.identifier ?? ""
    return countryCode == "US"
}
```

- Uses device locale settings
- No permissions required
- Checked at purchase time
- Can be spoofed by changing device region (testing)

---

## 🔄 A/B Testing Strategy

### Recommended Test:
1. **Control (50%):** `usestripesheet: false` (external)
2. **Variant (50%):** `usestripesheet: true` (native)

### Metrics to Track:
- Subscription start rate
- Trial start rate  
- Payment completion rate
- Time to purchase
- Drop-off rate at payment

### Expected Results:
- Native sheet: Higher completion (less friction)
- External: Potentially lower but more trusted UI

---

## 🚨 Common Issues

### Issue #1: 400 Error from Stripe
**Cause:** Key/mode mismatch  
**Solution:** Ensure iOS uses backend's `publishableKey`  
**Fix:** ✅ Now implemented

### Issue #2: PaymentSheet shows when it shouldn't
**Cause:** `usestripesheet` flag misconfigured  
**Solution:** Set to `false` for external checkout

### Issue #3: Wrong prices loaded
**Cause:** `useproductionmode` not matching intent  
**Solution:** Backend auto-selects price based on mode

### Issue #4: USA users seeing IAP
**Cause:** `stripepaywall: false`  
**Solution:** Set to `true` to enable Stripe for USA

---

## ✅ Verification Checklist

Before going live, verify:

- [ ] `useproductionmode: true` in Firebase
- [ ] Production Stripe keys configured in Firebase Secrets
- [ ] Test purchases work with `useproductionmode: false`
- [ ] Production merchant ID configured for Apple Pay
- [ ] Publishable key matches mode in logs
- [ ] USA detection working correctly
- [ ] Deep link handling works for external checkout
- [ ] Webhook configured for subscription confirmation

---

**Created:** November 13, 2025  
**Last Updated:** November 13, 2025

