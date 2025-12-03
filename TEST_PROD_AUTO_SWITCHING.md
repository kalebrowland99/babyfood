# 🔄 Automatic Test/Production Switching

## ✅ **Setup Complete!**

Your Firebase functions now **automatically detect** whether to use test or production configurations based on the Stripe API key.

---

## 🎯 How It Works

### **Single Control Point: Stripe API Key**

Everything switches based on which Stripe secret key is set:

```javascript
if (stripeKey.startsWith("sk_live")) {
  // Production mode
  ✅ Use production price IDs
  ✅ Use production webhook secret
} else {
  // Test mode
  ✅ Use test price IDs
  ✅ Use test webhook secret
}
```

---

## 📊 Current Configuration

### **Secrets in Firebase Secret Manager:**

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| `STRIPE_SECRET_KEY` | `sk_live_51SPohe...` | **Currently LIVE** - API key |
| `STRIPE_WEBHOOK_SECRET` | `whsec_fHYxmO...` | Production webhook verification |
| `STRIPE_WEBHOOK_SECRET_TEST` | `whsec_duFFF...` | Test webhook verification |

### **Price IDs (Hardcoded in Function):**

| Mode | Main Subscription | Winback Offer |
|------|-------------------|---------------|
| **Production** | `price_1SPpOGEAO5iISw7Sr6ytdoYP` ($149) | `price_1SQL9NEAO5iISw7Sr650SppU` ($79) |
| **Test** | `price_1SPpmQEAO5iISw7SKWdV84yy` | `price_1SPpmQEAO5iISw7SKWdV84yy` |

---

## 🔄 Switching Between Test and Production

### **Method 1: Switch to TEST Mode**

```bash
# Set test Stripe key
echo "sk_test_YOUR_TEST_KEY" | firebase functions:secrets:set STRIPE_SECRET_KEY

# Redeploy functions
firebase deploy --only functions:getStripeCheckoutUrl,functions:stripeWebhook
```

**Result:**
- ✅ Uses test price IDs automatically
- ✅ Uses test webhook secret automatically
- ✅ All checkouts go to Stripe test mode
- ✅ Webhooks verified with test secret

### **Method 2: Switch to PRODUCTION Mode** (Current)

```bash
# Set live Stripe key
echo "sk_live_51SPoheEAO5iISw7S..." | firebase functions:secrets:set STRIPE_SECRET_KEY

# Redeploy functions
firebase deploy --only functions:getStripeCheckoutUrl,functions:stripeWebhook
```

**Result:**
- ✅ Uses production price IDs automatically
- ✅ Uses production webhook secret automatically
- ✅ All checkouts go to Stripe live mode
- ✅ Webhooks verified with production secret

---

## 📱 iOS Remote Config

Your Firestore `paywall_config` also has test/prod URLs:

```
✅ stripecheckouturl (prod):      https://buy.stripe.com/8x2bJ14yl1kjfbL2Rt7Zu00
✅ stripecheckouturltest (test):  https://buy.stripe.com/test_8x2bJ14yl...
✅ winbackcheckouturl (prod):     https://buy.stripe.com/bJeaEXgh36ED4x777J7Zu01
✅ winbackcheckouturltest (test): https://buy.stripe.com/test_8x2bJ14...
```

**Note:** Since you're now using Firebase function to create checkout sessions (better approach), these URLs are **only used as fallback** if the function fails.

---

## 🧪 Testing Strategy

### **Development/Testing:**
1. Switch to test Stripe key
2. Deploy functions
3. Test with card: `4242 4242 4242 4242`
4. Check test webhook events in Stripe dashboard
5. Verify test mode in logs: `"Using TEST price"`

### **Production:**
1. Switch to live Stripe key
2. Deploy functions
3. Real payments processed
4. Check live webhook events in Stripe dashboard
5. Verify production mode in logs: `"Using PRODUCTION main price"`

---

## 🔍 Verification

### **Check Current Mode:**

View Firebase function logs after a checkout attempt:
```bash
firebase functions:log --only getStripeCheckoutUrl --lines 20
```

**Look for:**
```
Production Mode:
  💰 Using PRODUCTION main price
  🔗 Price ID: price_1SPpOGEAO5iISw7Sr6ytdoYP
  📊 Mode: PRODUCTION
```

```
Test Mode:
  💰 Using TEST price (main)
  🔗 Price ID: price_1SPpmQEAO5iISw7SKWdV84yy
  📊 Mode: TEST
```

### **Check Webhook Mode:**

View webhook logs:
```bash
firebase functions:log --only stripeWebhook --lines 20
```

**Look for:**
```
Production:
  🔐 Using PRODUCTION webhook secret
```

```
Test:
  🔐 Using TEST webhook secret
```

---

## ⚙️ What Gets Switched Automatically

| Component | Test Mode | Production Mode |
|-----------|-----------|-----------------|
| **Stripe API Key** | `sk_test_...` | `sk_live_...` ✅ |
| **Main Price ID** | `price_1SPpmQ...` (test) | `price_1SPpOGE...` ($149) ✅ |
| **Winback Price ID** | `price_1SPpmQ...` (test) | `price_1SQL9N...` ($79) ✅ |
| **Webhook Secret** | `whsec_duFFF...` (test) | `whsec_fHYxm...` (prod) ✅ |
| **Stripe Dashboard** | Test mode | Live mode ✅ |
| **Payment Cards** | Test cards only | Real cards ✅ |

---

## 🎯 Benefits

### **No Manual Configuration Changes:**
- ✅ Change ONE secret → Everything switches
- ✅ No code changes needed
- ✅ No price ID updates
- ✅ No webhook secret updates
- ✅ Safe and automatic

### **Prevention of Mistakes:**
- ✅ Can't mix test prices with live key
- ✅ Can't mix test webhook with live events
- ✅ Everything stays in sync
- ✅ Clear logging shows which mode

### **Easy Development Workflow:**
1. Develop with test key
2. Test thoroughly
3. Switch to live key for production
4. Deploy
5. Done! 🎉

---

## 🚨 Important Notes

### **Always Deploy After Switching:**
```bash
# After changing STRIPE_SECRET_KEY, ALWAYS:
firebase deploy --only functions:getStripeCheckoutUrl,functions:stripeWebhook
```

Running functions need to be redeployed to pick up new secrets.

### **Webhook URLs Stay the Same:**
- Production webhook URL: `https://stripewebhook-xhxqzuqe3q-uc.a.run.app`
- Test webhook URL: Same URL!

Both test and production webhooks use the **same endpoint**. The function automatically uses the right secret based on the Stripe key.

**Set up BOTH webhooks in Stripe:**
1. Go to test dashboard → Add webhook → Use function URL
2. Go to live dashboard → Add webhook → Use function URL

---

## 📝 Quick Reference

### **Currently Using:**
```
✅ PRODUCTION MODE
   - Live Stripe key: sk_live_51SPohe...
   - Production prices: $149 main, $79 winback
   - Production webhook secret
```

### **To Switch to Test:**
```bash
echo "sk_test_YOUR_TEST_KEY" | firebase functions:secrets:set STRIPE_SECRET_KEY
firebase deploy --only functions:getStripeCheckoutUrl,functions:stripeWebhook
```

### **To Switch Back to Production:**
```bash
echo "sk_live_YOUR_LIVE_KEY_HERE" | firebase functions:secrets:set STRIPE_SECRET_KEY
firebase deploy --only functions:getStripeCheckoutUrl,functions:stripeWebhook
```

---

**Setup Complete!** 🎉  
**Date**: November 6, 2025  
**Status**: ✅ Automatic test/prod switching enabled

