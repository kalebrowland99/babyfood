# 🚀 Quick Setup: Dynamic Pricing (5 Minutes)

This is a simplified guide to get dynamic pricing working quickly.

---

## ✅ What You'll Achieve

Switch between two pricing tiers instantly via Firebase Console:
- **Tier 1 (Old)**: Your current pricing
- **Tier 2 (New)**: $9.99 main subscription, $4.99 winback offer

---

## 📋 Prerequisites

- Firebase project is set up and connected
- Stripe prices already created with the following IDs:
  - `price_1Sa0MTEAO5iISw7SKeYn77np` ($9.99 with 3-day trial)
  - `price_1Sa0NTEAO5iISw7Sic1M8dOC` ($4.99 with 3-day trial)

---

## 🎯 Step-by-Step Setup

### Step 1: Update Firestore Document (2 minutes)

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select project: **thrift-882cb**
3. Click **Firestore Database** in sidebar
4. Navigate to: `app_config` → `paywall_config`
5. Click **Edit** (pencil icon)
6. Add these **3 new fields**:

| Field Name | Type | Value |
|------------|------|-------|
| `9dollarpricing` | boolean | `false` |
| `newmainpriceid` | string | `price_1Sa0MTEAO5iISw7SKeYn77np` |
| `newwinbackpriceid` | string | `price_1Sa0NTEAO5iISw7Sic1M8dOC` |
| `removetrial` | boolean | `false` |

7. Click **Update**

**Done! ✅**

---

### Step 2: Deploy Firebase Functions (1 minute)

The code is already updated, just need to deploy:

```bash
cd /Users/elianasilva/Desktop/thrift/functions
firebase deploy --only functions:createStripePaymentSheet,functions:getStripeCheckoutUrl
```

Wait for deployment to complete (~30 seconds).

---

### Step 3: Test the Setup (2 minutes)

#### Test with OLD pricing (default):

1. Open your app
2. Try to subscribe
3. Check Firebase function logs:

```bash
firebase functions:log --follow
```

You should see:
```
🎯 Using $9 pricing: false
🎯 Remove trial: false
💰 Using OLD pricing tier
🎁 Including 3-day free trial
```

#### Test with NEW pricing:

1. Go back to Firebase Console → Firestore
2. Edit `app_config/paywall_config`
3. Change `9dollarpricing` from `false` to `true`
4. Click **Update**
5. Wait 10 seconds for cache to clear
6. Open your app again (force close first)
7. Try to subscribe
8. Check logs again:

```bash
firebase functions:log --follow
```

You should see:
```
🎯 Using $9 pricing: true
🎯 Remove trial: false
💰 Using $9 pricing tier: $9.99 main
💰 Price ID: price_1Sa0MTEAO5iISw7SKeYn77np
🎁 Including 3-day free trial
```

**Success! 🎉**

---

## 🎛️ How to Switch Pricing (Anytime)

### Switch to NEW pricing ($9.99/$4.99):

1. Firebase Console → Firestore → `app_config/paywall_config`
2. Set `9dollarpricing` to `true`
3. Click Update
4. **Done!** Takes effect immediately.

### Switch to OLD pricing:

1. Firebase Console → Firestore → `app_config/paywall_config`
2. Set `9dollarpricing` to `false`
3. Click Update
4. **Done!** Takes effect immediately.

---

## 📊 What Happens When You Switch

When `9dollarpricing = true`:
- ✅ Main subscription button charges **$9.99**
- ✅ Winback offer button charges **$4.99**
- ✅ Both include 3-day free trial (unless `removetrial = true`)
- ✅ Changes apply to new purchases immediately
- ✅ Existing subscriptions are not affected

When `9dollarpricing = false`:
- ✅ Reverts to your old pricing
- ✅ Everything else stays the same

When `removetrial = true`:
- ✅ Removes 3-day free trial from ALL subscriptions
- ✅ Users are charged immediately at checkout
- ✅ Applies to both main and winback offers
- ✅ Works with both old and new pricing

When `removetrial = false`:
- ✅ Includes 3-day free trial (default behavior)
- ✅ Users charged after trial ends

---

## 🐛 Troubleshooting

### "Field not found" error in functions

**Solution**: Make sure you spelled the field names correctly (all lowercase, no spaces):
- `9dollarpricing` ✅
- `9DollarPricing` ❌
- `9_dollar_pricing` ❌

### App still using old pricing

**Solution**: 
1. Force close the app completely
2. Wait 30 seconds
3. Reopen the app
4. Try again

### Function deployment fails

**Solution**:
```bash
# Make sure you're in the functions directory
cd /Users/elianasilva/Desktop/thrift/functions

# Check you're logged in
firebase login

# Try deploying again
firebase deploy --only functions
```

---

## ✨ Pro Tips

1. **Start with `false`**: Keep `9dollarpricing = false` initially, monitor baseline metrics
2. **A/B Test**: Switch to `true` after 1-2 weeks, compare conversion rates
3. **Monitor Logs**: Keep function logs open while testing to see exactly what's happening
4. **Quick Rollback**: Can revert to old pricing instantly if needed
5. **No App Update**: Changes take effect without submitting new app version to App Store

---

## 📈 Recommended Testing Flow

**Week 1-2**: `9dollarpricing = false` (Baseline)
- Track conversion rate
- Track trial-to-paid conversion
- Track average revenue per user

**Week 3-4**: `9dollarpricing = true` (New Pricing)
- Compare metrics to baseline
- Monitor user feedback
- Track overall revenue

**Week 5**: Decision Time
- If new pricing performs better → Keep it!
- If old pricing was better → Switch back!
- Can toggle anytime based on data

---

## 🎯 Quick Reference

| Action | Steps |
|--------|-------|
| Enable new pricing | Firestore → Set `9dollarpricing = true` |
| Disable new pricing | Firestore → Set `9dollarpricing = false` |
| Remove trial period | Firestore → Set `removetrial = true` |
| Re-enable trial | Firestore → Set `removetrial = false` |
| Change $9.99 price | Firestore → Edit `newmainpriceid` |
| Change $4.99 price | Firestore → Edit `newwinbackpriceid` |
| View logs | `firebase functions:log --follow` |
| Redeploy functions | `firebase deploy --only functions` |

---

## ✅ Checklist

Before going live:
- [ ] Added 4 fields to Firestore `app_config/paywall_config`
- [ ] Deployed Firebase functions successfully
- [ ] Tested with `9dollarpricing = false` (old pricing works)
- [ ] Tested with `9dollarpricing = true` (new pricing works)
- [ ] Tested with `removetrial = true` (no trial works)
- [ ] Tested with `removetrial = false` (trial included)
- [ ] Confirmed function logs show correct pricing
- [ ] Ready to monitor conversion metrics

---

## 🎊 You're All Set!

Your dynamic pricing system is now live. You can switch between pricing tiers instantly via Firebase Console without any code changes or app updates.

**Current Status**: Using `9dollarpricing = false` (old pricing)

**To activate new pricing**: Set `9dollarpricing = true` in Firebase Console

Happy testing! 🚀

