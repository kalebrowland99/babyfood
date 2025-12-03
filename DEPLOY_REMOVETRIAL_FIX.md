# ⚠️ OBSOLETE - SEE DEPLOY_NOW.md

**This document described manual steps to create separate price IDs.**  
**A simpler solution was found that doesn't require new prices!**

**→ See `DEPLOY_NOW.md` for the correct deployment**  
**→ See `CRITICAL_FIX_TRIAL_OVERRIDE.md` for technical details**

---

# 🚀 Deploy RemoveTrial Fix - Action Items (OBSOLETE)

## ✅ What's Already Done

- ✅ Firebase function updated to dynamically choose price IDs
- ✅ iOS app updated to show dynamic UI text
- ✅ StripeSheetView updated to hide/show trial section
- ✅ Main subscription and winback text are now dynamic

---

## 🎯 What You Need to Do (3 Steps)

### Step 1: Create No-Trial Prices in Stripe Dashboard

1. Go to [Stripe Dashboard](https://dashboard.stripe.com/) → **Products**
2. Find your "Thrifty Premium" product
3. Click **Add another price** for each of these:

#### Price 1: $9.99 Main (NO TRIAL)
```
Price: $9.99 USD
Billing period: Weekly (or Yearly - match your existing)
Trial period: LEAVE BLANK ⚠️ (This is critical!)
```
**After creating, COPY THE PRICE ID** → `price_xxxxxxxxx`

#### Price 2: $4.99 Winback (NO TRIAL)
```
Price: $4.99 USD
Billing period: Weekly (or Yearly - match your existing)
Trial period: LEAVE BLANK ⚠️
```
**After creating, COPY THE PRICE ID** → `price_yyyyyyyyy`

#### Optional: Old Pricing No-Trial Prices
If you're still using old pricing (`9dollarpricing = false`), create no-trial versions for those too:
```
Price: $149.00 USD (main)
Price: $79.00 USD (winback)
Trial period: LEAVE BLANK ⚠️
```

---

### Step 2: Add Price IDs to Firebase Config

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Navigate to **Firestore Database**
3. Go to `app_config` → `paywall_config`
4. Click **Edit**
5. Add these NEW fields:

```
newmainpriceidnotrial: "price_xxxxxxxxx"      (the $9.99 NO-trial price ID from Step 1)
newwinbackpriceidnotrial: "price_yyyyyyyyy"   (the $4.99 NO-trial price ID from Step 1)
```

**Optional** (if using old pricing):
```
oldmainpriceidnotrial: "price_zzzzzzzzz"
oldwinbackpriceidnotrial: "price_aaaaaaaa"
```

6. Make sure `removetrial` is set to `true` or `false` (boolean):
```
removetrial: true    (to remove trial - immediate charge)
```

7. Click **Update**

---

### Step 3: Deploy Firebase Functions

```bash
cd /Users/elianasilva/Desktop/thrift/functions
firebase deploy --only functions:getStripeCheckoutUrl,functions:createStripePaymentSheet
```

Wait for deployment to complete (~1-2 minutes).

---

## 🧪 Testing

### Test 1: No-Trial Flow

1. In Firebase config, set:
```
removetrial: true
```

2. Force close and reopen your app

3. Tap subscribe button

4. Check Firebase logs:
```bash
firebase functions:log --follow
```

**Expected logs:**
```
🎯 Remove trial: true
💰 Using $9 pricing tier (NO TRIAL): $9.97 main
⚡ No trial - immediate charge
```

5. In Stripe checkout page:
- Should show immediate charge
- NO mention of "free trial"
- Subscription starts today

6. Check iOS app UI:
- Button should say "Subscribe Now"
- Disclaimer should say "Just $9.99 per year. Cancel anytime."
- StripeSheet should NOT show "3-day free trial" section

### Test 2: With-Trial Flow

1. In Firebase config, set:
```
removetrial: false
```

2. Force close and reopen your app

3. Tap subscribe button

4. Check Firebase logs:
```
🎯 Remove trial: false
💰 Using $9 pricing tier (WITH TRIAL): $9.97 main
🎁 Including 3-day free trial
```

5. In Stripe checkout page:
- Should show "Start free trial"
- Billing starts in 3 days

6. Check iOS app UI:
- Button should say "Try FREE for 3 days" (or your custom text)
- Disclaimer should show trial messaging
- StripeSheet should show "3-day free trial" section

---

## 📊 Current Configuration Summary

| Config Field | Current Value | Notes |
|-------------|---------------|-------|
| `9dollarpricing` | `true` | Using $9 pricing tier |
| `removetrial` | `true` | Trial is REMOVED |
| `newmainpriceid` | `price_1Sa0MTEAO5iISw7SKeYn77np` | $9.99 WITH trial |
| `newwinbackpriceid` | `price_1Sa0NTEAO5iISw7Sic1M8dOC` | $4.99 WITH trial |
| `newmainpriceidnotrial` | ❌ **YOU NEED TO ADD** | $9.99 NO trial |
| `newwinbackpriceidnotrial` | ❌ **YOU NEED TO ADD** | $4.99 NO trial |

---

## ⚠️ Critical Understanding

**Why your trial still shows:**

Your current Stripe prices (`price_1Sa0MTEAO5iISw7SKeYn77np` and `price_1Sa0NTEAO5iISw7Sic1M8dOC`) were created with `recurring.trial_period_days = 3` **built into the price**.

This is a **permanent setting** on the price itself. You cannot override it via the checkout session.

**The only solution** is to create NEW prices without trials, then dynamically choose which price to use based on the `removetrial` flag.

---

## 🎛️ How It Works After Fix

### Architecture:

```
User clicks subscribe
       ↓
iOS app calls Firebase function
       ↓
Function reads Firebase config
       ↓
IF removetrial = true:
  → Use no-trial price IDs (newmainpriceidnotrial)
  → Don't add trial_period_days to session
  → Return hasTrial: false
       ↓
IF removetrial = false:
  → Use with-trial price IDs (newmainpriceid)
  → Add trial_period_days: 3 to session
  → Return hasTrial: true
       ↓
iOS app shows dynamic UI text
       ↓
Stripe checkout created with correct configuration
```

---

## 📝 Quick Reference

**To REMOVE trial** (immediate charge):
```
1. Set removetrial: true in Firebase
2. Make sure newmainpriceidnotrial exists
3. UI will show "Subscribe Now"
4. Stripe will charge immediately
```

**To INCLUDE trial** (3-day free):
```
1. Set removetrial: false in Firebase
2. Uses existing newmainpriceid (with trial)
3. UI will show "Try FREE for 3 days"
4. Stripe will start 3-day trial
```

---

## 🔧 Troubleshooting

### Issue: Still showing trial after setting removetrial = true

**Check:**
1. Did you create no-trial prices in Stripe? (Step 1)
2. Did you add the new price IDs to Firebase? (Step 2)
3. Did you deploy the functions? (Step 3)
4. Did you force close and reopen the app?

**Verify in Firebase logs:**
```bash
firebase functions:log --follow
```

Look for:
```
💰 Using $9 pricing tier (NO TRIAL): $9.97 main
```

If it still says "(WITH TRIAL)", the function isn't finding the no-trial price IDs.

### Issue: Firebase function errors

Check that the new fields are spelled correctly:
- `newmainpriceidnotrial` (all lowercase, no spaces)
- `newwinbackpriceidnotrial` (all lowercase, no spaces)

### Issue: UI still shows trial text

The app caches the `remoteConfig`. Try:
1. Force close app completely
2. Delete app and reinstall
3. Wait 30 seconds for Firebase to propagate

---

## ✅ Success Checklist

- [ ] Created no-trial prices in Stripe Dashboard
- [ ] Copied price IDs
- [ ] Added `newmainpriceidnotrial` to Firebase config
- [ ] Added `newwinbackpriceidnotrial` to Firebase config
- [ ] Deployed Firebase functions
- [ ] Tested no-trial flow (`removetrial = true`)
- [ ] Tested with-trial flow (`removetrial = false`)
- [ ] Verified in Firebase logs
- [ ] Verified UI text changes dynamically
- [ ] Verified Stripe checkout behaves correctly

---

## 🎉 Expected Results

### When `removetrial = true`:

**iOS App:**
- Button: "Subscribe Now"
- Disclaimer: "Just $9.99 per year. Cancel anytime."
- StripeSheet: NO "3-day free trial" section
- Pricing shows: "Starting today"

**Stripe Checkout:**
- Immediate charge
- No trial period mentioned
- Subscription starts immediately

**Firebase Logs:**
```
🎯 Remove trial: true
💰 Using $9 pricing tier (NO TRIAL): $9.97 main
💰 Price ID: price_xxxxxxxxx (your no-trial price)
⚡ No trial - immediate charge
```

### When `removetrial = false`:

**iOS App:**
- Button: "Try FREE for 3 days"
- Disclaimer: "Free for 3 days, then $9.99 per year"
- StripeSheet: Shows "3-day free trial" section
- Pricing shows: "Starting [date in 3 days]"

**Stripe Checkout:**
- Shows trial period
- Charge in 3 days
- User can try before paying

**Firebase Logs:**
```
🎯 Remove trial: false
💰 Using $9 pricing tier (WITH TRIAL): $9.97 main
💰 Price ID: price_1Sa0MTEAO5iISw7SKeYn77np
🎁 Including 3-day free trial
```

---

**Created**: December 2, 2025  
**Status**: Ready to deploy  
**Next Step**: Complete Step 1 (Create Stripe prices)

