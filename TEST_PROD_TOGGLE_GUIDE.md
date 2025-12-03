# 🔄 Instant Test/Production Mode Toggle

## Overview

Switch between test and production modes **instantly** by changing a single flag in Firestore. No code deployment needed!

---

## ✨ How It Works

The app now has a **smart mode switcher** that automatically selects the right URLs based on `useproductionmode`:

```
useproductionmode = true  → Uses production URLs
useproductionmode = false → Uses test URLs
```

**What automatically switches:**
- ✅ Stripe checkout URL (main subscription)
- ✅ Winback offer URL
- ✅ App reads from correct URLs instantly

**What you still need to manually switch:**
- Apple environment (SANDBOX vs PRODUCTION) - backend only
- Stripe webhook secret - backend only

---

## 📝 Firestore Configuration

### Structure in `app_config/paywall_config`:

```json
{
  "useproductionmode": true,
  
  // Production URLs
  "stripecheckouturl": "https://buy.stripe.com/8x2bJ14yl1kjfbL2Rt7Zu00",
  "winbackcheckouturl": "https://buy.stripe.com/bJeaEXgh36ED4x777J7Zu01",
  
  // Test URLs
  "stripecheckouturltest": "https://buy.stripe.com/test/XXXXXXXXXXXX",
  "winbackcheckouturltest": "https://buy.stripe.com/test/YYYYYYYYYYYY",
  
  // Other config...
  "hardpaywall": true,
  "stripepaywall": true,
  "stripebuttontext": "Try free for 3 days",
  "stripedisclaimertext": "Your disclaimer text",
  "winbackdisclaimertext": "Winback disclaimer text"
}
```

---

## 🚀 Quick Start Setup

### Step 1: Add Test URLs to Firestore

1. Go to: https://console.firebase.google.com/project/thrift-882cb/firestore
2. Navigate to: `app_config` → `paywall_config`
3. Add these new fields:

```
Field: stripecheckouturltest
Type: string
Value: [Your Stripe test checkout URL]

Field: winbackcheckouturltest  
Type: string
Value: [Your Stripe test winback URL]

Field: useproductionmode
Type: boolean
Value: true (for production)
```

### Step 2: Switch Modes Anytime

**To switch to TEST mode:**
1. Go to Firestore: `app_config/paywall_config`
2. Change `useproductionmode` to `false`
3. **That's it!** App automatically uses test URLs

**To switch to PRODUCTION mode:**
1. Go to Firestore: `app_config/paywall_config`
2. Change `useproductionmode` to `true`
3. **That's it!** App automatically uses production URLs

---

## 📊 Mode Comparison

| Mode | Stripe URLs | Apple IAP | Webhooks |
|------|-------------|-----------|----------|
| **Production** | Live Stripe products | Real purchases | Production webhook |
| **Test** | Test Stripe products | Sandbox purchases | Test webhook |

---

## 🎯 Use Cases

### 1. Testing Before Going Live
```
useproductionmode: false
→ Safe testing with test Stripe products
→ No real charges
```

### 2. Production (Live)
```
useproductionmode: true
→ Real Stripe charges
→ Live production mode
```

### 3. Quick Rollback
If something goes wrong:
```
1. Set useproductionmode: false
2. App instantly switches to test mode
3. No deployment needed!
```

### 4. A/B Testing
Test new checkout flows:
```
1. Set up new test URLs
2. Switch to test mode
3. Test thoroughly
4. Switch back to production
```

---

## 🔍 How the App Selects URLs

```swift
if useproductionmode == true {
    stripeCheckoutUrl = stripecheckouturl (production)
    winbackCheckoutUrl = winbackcheckouturl (production)
} else {
    stripeCheckoutUrl = stripecheckouturltest (test)
    winbackCheckoutUrl = winbackcheckouturltest (test)
}
```

The app automatically loads the correct URLs when:
- App launches
- Remote config refreshes
- User pulls to refresh (if implemented)

---

## ⚡ Instant Switching Process

### From Your Perspective:

1. Open Firestore
2. Toggle `useproductionmode`
3. Done!

### What Happens Behind the Scenes:

1. User opens app
2. App loads remote config from Firestore
3. Checks `useproductionmode` value
4. Automatically selects correct URLs
5. User sees correct checkout pages

**No app restart needed!** (on next remote config load)

---

## 🛡️ Safety Features

✅ **Default to Production**: If flag is missing, defaults to `true` (production)  
✅ **Fallback URLs**: If test URLs missing, uses defaults  
✅ **Logging**: Console shows which mode is active  
✅ **Type Safety**: Boolean flag prevents typos  

---

## 📝 Complete Configuration Example

```json
{
  // ===== MODE TOGGLE =====
  "useproductionmode": true,
  
  // ===== PRODUCTION URLs =====
  "stripecheckouturl": "https://buy.stripe.com/8x2bJ14yl1kjfbL2Rt7Zu00",
  "winbackcheckouturl": "https://buy.stripe.com/bJeaEXgh36ED4x777J7Zu01",
  
  // ===== TEST URLs =====
  "stripecheckouturltest": "https://buy.stripe.com/test/abc123",
  "winbackcheckouturltest": "https://buy.stripe.com/test/xyz789",
  
  // ===== OTHER CONFIG =====
  "hardpaywall": true,
  "stripepaywall": true,
  "stripebuttontext": "Try free for 3 days",
  "stripedisclaimertext": "Free for 3 days, then $149/year",
  "winbackdisclaimertext": "Special offer! Free for 3 days, then $79/year"
}
```

---

## 🐛 Troubleshooting

### Issue: App still uses production URLs after switching to test

**Solution:**
1. Force quit the app
2. Reopen (triggers config reload)
3. Check console logs for "Using TEST stripeCheckoutUrl"

### Issue: Test URLs not working

**Check:**
1. `stripecheckouturltest` field exists in Firestore
2. URL is valid Stripe test link (contains `/test/`)
3. `useproductionmode` is set to `false`

### Issue: Don't see which mode is active

**View logs:**
Look for these in Xcode console:
```
✅ Using PRODUCTION stripeCheckoutUrl: [url]
OR
✅ Using TEST stripeCheckoutUrl: [url]
```

---

## 🔄 Backend Switching (Still Manual)

For complete test mode, you also need to:

### 1. Apple Environment
```bash
firebase functions:config:set apple.environment="SANDBOX"
firebase deploy --only functions
```

### 2. Stripe Webhook Secret
```bash
# Use test webhook secret
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
# [paste test secret: whsec_test_...]
firebase deploy --only functions:stripeWebhook
```

**But for most testing, just toggling `useproductionmode` is enough!**

---

## 💡 Pro Tips

1. **Keep Both URLs Updated**: Always maintain both test and production URLs
2. **Test First**: Use test mode to verify new checkout flows
3. **Monitor Logs**: Check which mode app is using
4. **Quick Rollback**: Can switch to test mode if production issues arise
5. **No Deployment**: URL changes take effect on next app load

---

## 📚 Summary

**Before this feature:**
- ❌ Manual URL updates in Firestore
- ❌ Switch between 4 different fields
- ❌ Risk of using wrong URLs

**After this feature:**
- ✅ One boolean flag controls everything
- ✅ Instant switching (no deployment)
- ✅ Safe defaults
- ✅ Clear logging

---

## 🎯 Quick Reference

| Task | Action |
|------|--------|
| **Switch to Test** | Set `useproductionmode: false` |
| **Switch to Production** | Set `useproductionmode: true` |
| **Check Current Mode** | View Xcode console logs |
| **Add Test URLs** | Add `stripecheckouturltest` + `winbackcheckouturltest` |

---

**Created**: November 6, 2025  
**Status**: Ready to use! ✅  
**Deployment**: Not required - works immediately

