# ⚠️ OBSOLETE - SEE CRITICAL_FIX_TRIAL_OVERRIDE.md

**This document described a complex solution (separate price IDs).**  
**A simpler solution was found: explicitly set `trial_period_days: 0`**

**→ See `CRITICAL_FIX_TRIAL_OVERRIDE.md` for the correct solution**  
**→ See `DEPLOY_NOW.md` for deployment instructions**

---

# 🔧 Fix RemoveTrial Issue - Complete Guide (OBSOLETE)

## 🎯 The Problem

**Root Cause**: Your Stripe price IDs have **trials built into the price itself**, which cannot be overridden by the `removetrial` flag.

**Three-Layer Problem**:
1. ✅ Backend correctly checks `removetrial` flag
2. ❌ Stripe prices have trials baked in at price level
3. ❌ UI text is static and doesn't change with `removetrial`

## 🔍 Why It's Not Working

### Current Stripe Prices:
```
Main:    price_1Sa0MTEAO5iISw7SKeYn77np ($9.99 with trial)
Winback: price_1Sa0NTEAO5iISw7Sic1M8dOC ($4.99 with trial)
```

These prices were created with `recurring.trial_period_days = 3` **at the price level**.

**Key Insight**: 
- When a price has a trial configured, that's **permanent**
- Setting `trial_period_days` in the checkout session won't remove it
- You need separate price IDs for with-trial vs no-trial

---

## ✅ The Solution

Create **TWO SETS** of prices:
1. **WITH TRIAL** (existing) - For `removetrial = false`
2. **WITHOUT TRIAL** (new) - For `removetrial = true`

Then **dynamically choose** which price to use based on the flag.

---

## 🚀 Step-by-Step Fix

### Step 1: Create No-Trial Prices in Stripe

1. Go to [Stripe Dashboard](https://dashboard.stripe.com/)
2. Navigate to **Products**
3. Find your "Thrifty Premium" product
4. Click **Add another price**

#### For $9.99 Main (No Trial):
```
Price model: Standard pricing
Price: $9.99 USD
Billing period: Weekly
Trial period: LEAVE BLANK (this is critical!)
```
**Copy the price ID** (e.g., `price_xxxxxxxxxxxxx`)

#### For $4.99 Winback (No Trial):
```
Price model: Standard pricing
Price: $4.99 USD
Billing period: Weekly
Trial period: LEAVE BLANK
```
**Copy the price ID** (e.g., `price_yyyyyyyyyyyyy`)

### Step 2: Add New Price IDs to Firebase Config

1. Go to Firebase Console → Firestore Database
2. Navigate to `app_config` → `paywall_config`
3. Click **Edit**
4. Add these new fields:

```
newmainpriceidnotrial: "price_xxxxxxxxxxxxx"
newwinbackpriceidnotrial: "price_yyyyyyyyyyyyy"
```

5. Click **Update**

Your config should now have:
```
9dollarpricing: true
removetrial: true
newmainpriceid: "price_1Sa0MTEAO5iISw7SKeYn77np" (WITH trial)
newwinbackpriceid: "price_1Sa0NTEAO5iISw7Sic1M8dOC" (WITH trial)
newmainpriceidnotrial: "price_xxxxxxxxxxxxx" (NO trial)
newwinbackpriceidnotrial: "price_yyyyyyyyyyyyy" (NO trial)
```

### Step 3: Update Firebase Functions

Update `functions/index.js` to dynamically choose price IDs:

**Find this section** (around line 1640):
```javascript
if (use9DollarPricing) {
  // $9 pricing: $9.97 main, $4.99 winback (hardcoded)
  priceId = isWinback 
    ? "price_1Sa0NTEAO5iISw7Sic1M8dOC" // $4.99 winback
    : "price_1Sa0MTEAO5iISw7SKeYn77np"; // $9.97 main
  console.log(`💰 Using $9 pricing tier: ${isWinback ? "$4.99 winback" : "$9.97 main"}`);
}
```

**Replace with**:
```javascript
if (use9DollarPricing) {
  // Choose price based on removeTrial flag
  if (removeTrial) {
    // Use NO-TRIAL prices
    priceId = isWinback 
      ? (config.newwinbackpriceidnotrial || "price_1Sa0NTEAO5iISw7Sic1M8dOC") // $4.99 winback NO trial
      : (config.newmainpriceidnotrial || "price_1Sa0MTEAO5iISw7SKeYn77np"); // $9.97 main NO trial
    console.log(`💰 Using $9 pricing tier (NO TRIAL): ${isWinback ? "$4.99 winback" : "$9.97 main"}`);
  } else {
    // Use WITH-TRIAL prices
    priceId = isWinback 
      ? "price_1Sa0NTEAO5iISw7Sic1M8dOC" // $4.99 winback WITH trial
      : "price_1Sa0MTEAO5iISw7SKeYn77np"; // $9.97 main WITH trial
    console.log(`💰 Using $9 pricing tier (WITH TRIAL): ${isWinback ? "$4.99 winback" : "$9.97 main"}`);
  }
}
```

**Do the same for the other occurrence** around line 1520 (in createStripePaymentSheet function).

### Step 4: Update UI Text to be Dynamic

Update Firebase config to have dynamic text:

1. Firebase Console → Firestore → `app_config/paywall_config`
2. Update these fields:

**When `removetrial = true`**:
```
stripebuttontext: "Subscribe Now"
stripedisclaimertext: "Just $9.99 a week"
winbackdisclaimertext: "Just $4.99 a week"
```

**When `removetrial = false`**:
```
stripebuttontext: "Try FREE for 3 days"
stripedisclaimertext: "Free for 3 days, then $9.99 a week"
winbackdisclaimertext: "Free for 3 days, then $4.99 a week"
```

### Step 5: Deploy Firebase Functions

```bash
cd functions
firebase deploy --only functions:getStripeCheckoutUrl,functions:createStripePaymentSheet
```

---

## 📊 Testing

### Test No-Trial Flow (`removetrial = true`):

1. Set in Firebase:
```
removetrial: true
stripebuttontext: "Subscribe Now"
stripedisclaimertext: "Just $9.99 a week"
```

2. Open app and click subscribe button

3. Check Firebase logs:
```bash
firebase functions:log --follow
```

Should see:
```
🎯 Remove trial: true
💰 Using $9 pricing tier (NO TRIAL): $9.97 main
⚡ No trial - immediate charge
```

4. In Stripe checkout, should show:
- **NO mention of free trial**
- Immediate charge
- Subscription starts today

### Test With-Trial Flow (`removetrial = false`):

1. Set in Firebase:
```
removetrial: false
stripebuttontext: "Try FREE for 3 days"
stripedisclaimertext: "Free for 3 days, then $9.99 a week"
```

2. Open app and click subscribe

3. Should see in logs:
```
🎯 Remove trial: false
💰 Using $9 pricing tier (WITH TRIAL): $9.97 main
🎁 Including 3-day free trial
```

4. In Stripe checkout, should show:
- "Start free trial"
- 3-day trial period
- Billing starts in 3 days

---

## 🎯 Summary of Changes

| Component | Change | Status |
|-----------|--------|--------|
| Stripe Prices | Created no-trial versions | ✅ (You need to do) |
| Firebase Config | Added new price IDs | ✅ (You need to do) |
| Firebase Function | Dynamic price selection | ✅ (Code below) |
| UI Text | Make dynamic | ✅ (You need to do) |
| Testing | Both flows work | ✅ (After changes) |

---

## ⚠️ Critical Points

1. **Price-level trial CANNOT be overridden** - This is why you need separate prices
2. **Session-level trial ONLY works** when price has NO trial configured
3. **UI text is separate** - Update Firebase config manually or make it dynamic in code
4. **Test mode vs Production** - Create no-trial prices in BOTH environments

---

## 🔍 Why This Happens

**Stripe's Trial Precedence**:
1. If price has trial → **ALWAYS use it** (can't override)
2. If price has NO trial → Session can add trial via `trial_period_days`

Your current setup:
- Prices have trials built in ❌
- Backend tries to remove trial via session ❌ (won't work)
- Result: Trial always shows ❌

Fixed setup:
- Two sets of prices (with/without trial) ✅
- Backend chooses correct price ✅
- Result: Works as expected ✅

---

## 📞 Quick Reference

**To Remove Trial**:
1. Create no-trial prices in Stripe
2. Add price IDs to Firebase config
3. Set `removetrial = true`
4. Backend uses no-trial prices
5. Update UI text

**To Include Trial**:
1. Set `removetrial = false`
2. Backend uses with-trial prices
3. Update UI text

---

**Created**: December 2, 2025
**Status**: Ready to implement

