# 🔍 Check Your Stripe Price Configuration

## The Critical Question

**Is the trial configured IN the price itself, or just as a session default?**

This determines if we can override it with `trial_period_days: 0` or if we need separate price IDs.

---

## How to Check

### Option 1: Stripe CLI (Fastest)

```bash
stripe prices retrieve price_1Sa0MTEAO5iISw7SKeYn77np
```

**Look for this in the output:**

```json
{
  "id": "price_1Sa0MTEAO5iISw7SKeYn77np",
  "recurring": {
    "interval": "year",
    "trial_period_days": 3  ← THIS IS THE KEY
  }
}
```

### Option 2: Stripe Dashboard

1. Go to [Stripe Dashboard](https://dashboard.stripe.com/)
2. Navigate to **Products** → Click on "Thrifty Premium"
3. Find the price `price_1Sa0MTEAO5iISw7SKeYn77np`
4. Look at the **trial period** setting

**Two possible configurations:**

#### Configuration A: Trial in Price (Cannot Override)
```
Price: $9.99/year
Trial period: 3 days ← SET AT PRICE LEVEL
```
❌ **This CANNOT be overridden** by `trial_period_days: 0`  
✅ **Solution: Must create separate price without trial**

#### Configuration B: No Trial in Price (Can Override)
```
Price: $9.99/year
Trial period: None ← NOT SET AT PRICE LEVEL
```
✅ **This CAN be controlled** by `trial_period_days` in session  
✅ **Current fix will work**

---

## Why This Matters

### If Trial is IN the Price:

```javascript
// Price definition (in Stripe):
{
  id: "price_xxx",
  recurring: {
    interval: "year",
    trial_period_days: 3  // ← Built into the price
  }
}

// Your checkout session:
{
  line_items: [{ price: "price_xxx" }],
  subscription_data: {
    trial_period_days: 0  // ← This will be IGNORED!
  }
}

// Result: 3-day trial (price wins) ❌
```

### If Trial is NOT in the Price:

```javascript
// Price definition (in Stripe):
{
  id: "price_xxx",
  recurring: {
    interval: "year"
    // No trial_period_days
  }
}

// Your checkout session:
{
  line_items: [{ price: "price_xxx" }],
  subscription_data: {
    trial_period_days: 0  // ← This WORKS!
  }
}

// Result: No trial ✅
```

---

## What to Do Based on Results

### Result A: Trial IS in the price (recurring.trial_period_days exists)

**You need to:**
1. Create new prices WITHOUT trials:
   - Main: $9.99/year, NO trial
   - Winback: $4.99/year, NO trial
2. Add new price IDs to Firebase config
3. Update functions to choose price based on `removetrial` flag

**Follow:** `DEPLOY_REMOVETRIAL_FIX.md` (original solution was correct)

### Result B: Trial is NOT in the price

**Current fix should work:**
1. Just deploy the functions
2. Test with `removetrial = true`
3. Should see immediate charge

**Follow:** `DEPLOY_NOW.md`

---

## Quick Test Commands

### Check Main Price:
```bash
stripe prices retrieve price_1Sa0MTEAO5iISw7SKeYn77np
```

### Check Winback Price:
```bash
stripe prices retrieve price_1Sa0NTEAO5iISw7Sic1M8dOC
```

### Check Test Price:
```bash
stripe prices retrieve price_1SPpmQEAO5iISw7SKWdV84yy
```

---

## What I Suspect

Based on your symptom (Stripe still shows trial after setting `trial_period_days: 0`), I believe:

**Your prices have `recurring.trial_period_days` configured**, which means:
- ❌ The simple fix (`trial_period_days: 0`) won't work
- ✅ You need separate price IDs (original solution)

Please run the check command above to confirm!

---

**Next Steps:**

1. Run: `stripe prices retrieve price_1Sa0MTEAO5iISw7SKeYn77np`
2. Check if `recurring.trial_period_days` exists
3. Reply with the output
4. I'll give you the exact solution based on your configuration

---

**Created**: December 2, 2025  
**Purpose**: Diagnose the exact issue  
**Time**: 2 minutes to check

