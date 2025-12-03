# 🎨 Custom Stripe Sheet Setup Guide

> **⚠️ SUPERSEDED**: This document describes the old custom UI sheet that redirected to browser.  
> **See `STRIPE_NATIVE_PAYMENT_SETUP.md` for the NEW native in-app payment implementation.**

## Overview

This document describes the legacy custom sheet that mimicked Apple's UI but still redirected to external Stripe checkout. This has been replaced with a true native payment experience using the Stripe iOS SDK.

## ✅ What's Been Implemented

### 1. Debug Skip Button
- Added a "Skip" button to the first onboarding screen (SongFrequencyView)
- Located in the top-right corner of the header
- Allows you to quickly jump to the paywall for testing

### 2. Remote Config Flag
- **New Flag**: `useStripeSheet` (boolean)
- **Default**: `false` (external redirect)
- **When true**: Shows custom in-app sheet that mimics Apple UI
- **When false**: Redirects to external Stripe checkout URL

### 3. Custom Stripe Sheet (StripeSheetView)
A pixel-perfect recreation of Apple's subscription sheet featuring:
- "App Store" header with X button
- App icon display
- "Thrifty Unlimited" title
- "Thrifty: Scan & Flip Items 4+" subtitle
- "Subscription" label
- "3-day free trial" section with "Starting today"
- "$79.99 per year" pricing with calculated start date
- Terms text matching Apple's style
- User email and payment badge
- "Confirm with Side Button" blue button at bottom

## 🔧 Firebase Configuration

To enable the custom sheet, add this field to your Firestore `app_config/paywall_config` document:

```json
{
  "hardpaywall": true,
  "stripepaywall": true,
  "usestripesheet": false,
  "useproductionmode": true,
  "stripecheckouturl": "your-stripe-url",
  "winbackcheckouturl": "your-winback-url"
}
```

### Configuration Options

| Field | Type | Description |
|-------|------|-------------|
| `usestripesheet` | boolean | `true` = show custom sheet, `false` = external redirect |

## 🎯 How It Works

### Flow 1: External Redirect (usestripesheet = false)
1. User taps "Try for $0.00" button
2. App redirects to external Stripe checkout
3. User completes payment on Stripe website
4. Returns to app via deep link

### Flow 2: Custom Sheet (usestripesheet = true)
1. User taps "Try for $0.00" button
2. Custom Apple-style sheet appears
3. User reviews subscription details
4. User taps "Confirm with Side Button"
5. Sheet dismisses and redirects to Stripe checkout
6. User completes payment on Stripe website
7. Returns to app via deep link

## 🧪 Testing

### Test the Debug Button
1. Log in to the app
2. Navigate to onboarding (first screen)
3. Look for "Skip" button in top-right
4. Tap it to jump directly to paywall

### Test External Redirect
1. In Firebase Console, set `usestripesheet: false`
2. Restart app to load config
3. Navigate to paywall
4. Tap subscription button
5. Should open Safari/external browser

### Test Custom Sheet
1. In Firebase Console, set `usestripesheet: true`
2. Restart app to load config
3. Navigate to paywall
4. Tap subscription button
5. Should see Apple-style sheet
6. Tap "Confirm with Side Button"
7. Should open Safari/external browser

## 📝 Configuration Examples

### Standard External Flow (Current Default)
```json
{
  "usestripesheet": false
}
```

### New Custom Sheet Flow
```json
{
  "usestripesheet": true
}
```

## 🎨 Customization

The sheet displays:
- **Title**: "Thrifty Unlimited" (hardcoded)
- **Subtitle**: "Thrifty: Scan & Flip Items 4+" (hardcoded)
- **Trial Period**: 3 days (hardcoded)
- **Price**: $79.99 per year (hardcoded)
- **Start Date**: Calculated as today + 3 days
- **User Email**: Pulled from AuthenticationManager

To customize these values, edit the `StripeSheetView` in `ContentView.swift`:
- Line 10400: Title text
- Line 10406: Subtitle text
- Line 10431: Trial period text
- Line 10450: Pricing text
- Line 10455: Date calculation

## 🔍 Debugging

### Check Remote Config Loading
Look for these console logs:
```
✅ Config loaded from Firestore - useStripeSheet: true/false
```

### Check Sheet Display
Look for these console logs:
```
📱 Showing custom Stripe sheet (mimics Apple UI)...
```

### Check Stripe Redirect
Look for these console logs:
```
✅ Opened Stripe checkout from custom sheet
```

## 🚀 Benefits

### Custom Sheet Approach
- ✅ More native feeling experience
- ✅ Familiar Apple subscription UI
- ✅ User stays in app longer before redirect
- ✅ Can review details before committing to checkout
- ✅ Easier to A/B test vs external redirect

### External Redirect Approach
- ✅ Simpler implementation
- ✅ Fewer steps to checkout
- ✅ Faster time to payment

## 📊 Recommended A/B Test

Test both approaches to see which converts better:

**Variant A**: `usestripesheet: false` (external redirect)
**Variant B**: `usestripesheet: true` (custom sheet)

Track conversion rates and choose the winner!

## ⚠️ Important Notes

1. The sheet still uses Stripe for actual payments (not Apple IAP)
2. The sheet is cosmetic - payment happens on Stripe's site
3. This only affects USA users (controlled by `stripePaywall` flag)
4. The deep link return flow is the same for both approaches
5. The sheet appearance requires iOS 15+ for best styling

## 🔄 Migration Path

You can switch between modes at any time by changing the `usestripesheet` flag in Firebase. No app update required!

---

**Created**: November 11, 2025
**Last Updated**: November 11, 2025

