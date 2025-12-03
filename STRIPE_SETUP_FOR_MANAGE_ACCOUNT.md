# Stripe Setup for Manage Account Flows

## Overview
Your backend code is already implemented and uses several Stripe features. Here's what needs to be configured in Stripe to make the manage account flows work properly.

---

## ✅ What Your Backend Does

### 1. **Pause/Extend Subscription** (`pauseSubscription`)
**For Trial Users:**
- Extends `trial_end` by selected duration (1 or 4 weeks)
- Uses: `stripe.subscriptions.update()`

**For Paying Users:**
- Uses `pause_collection` with `mark_uncollectible` behavior
- Automatically resumes after selected duration
- Uses: `stripe.subscriptions.update()`

### 2. **Apply 50% Lifetime Discount** (`applyLifetimeDiscount`)
- Creates/retrieves a coupon called "LIFETIME50"
- 50% off forever duration
- Applies to subscription immediately
- Uses: `stripe.coupons.create()` and `stripe.subscriptions.update()`

### 3. **Cancel Subscription** (`cancelSubscription`)
- Sets `cancel_at_period_end: true`
- User keeps access until billing period ends
- Uses: `stripe.subscriptions.update()`

### 4. **Store Feedback** (`storeCancellationFeedback`)
- Saves cancellation reasons to Firestore
- No Stripe configuration needed

---

## 🔧 Required Stripe Configuration

### 1. **API Keys** (Already Set Up ✅)

Your code uses Firebase Secrets for API keys:
```javascript
stripeSecretKeyTest
stripeSecretKeyProd
stripePublishableKeyTest
stripePublishableKeyProd
```

**Verify:**
- Go to [Stripe Dashboard → Developers → API Keys](https://dashboard.stripe.com/apikeys)
- Confirm your secret keys are active
- Make sure they match what's stored in Firebase Functions secrets

---

### 2. **Subscription Pause Settings** ⏸️

**What it does:** Allows pausing subscriptions without canceling them

**Configuration:**

#### Option A: Enable in Stripe Dashboard (Recommended)
1. Go to [Stripe Dashboard → Settings → Billing](https://dashboard.stripe.com/settings/billing)
2. Scroll to **"Subscriptions and emails"**
3. Find **"Pausing subscriptions"**
4. **Enable** the feature
5. Configure:
   - **Default behavior:** Mark invoices as uncollectible (your code uses this)
   - **Maximum pause duration:** Set to 4 weeks or unlimited
   - **Resumption behavior:** Resume automatically at specified date (your code sets this)

#### Option B: No Configuration Needed
The `pause_collection` API is available by default. Your code will create the pause programmatically.

**What your code does:**
```javascript
await stripe.subscriptions.update(subscriptionId, {
  pause_collection: {
    behavior: "mark_uncollectible",  // Don't charge during pause
    resumes_at: timestamp              // Auto-resume date
  }
});
```

**Stripe Dashboard View:**
- Paused subscriptions will show as **"Paused"** status
- Will show resume date
- Invoices during pause won't be collected

---

### 3. **Coupons for Discounts** 💰

**What it does:** Applies 50% lifetime discount to subscriptions

**Configuration:**

Your code **automatically creates** the coupon if it doesn't exist:
```javascript
stripe.coupons.create({
  id: "LIFETIME50",
  percent_off: 50,
  duration: "forever",
  name: "50% Off Lifetime Discount"
});
```

#### Manual Setup (Optional):
1. Go to [Stripe Dashboard → Products → Coupons](https://dashboard.stripe.com/coupons)
2. Click **"Create coupon"**
3. Configure:
   - **Coupon ID:** `LIFETIME50` (must match code)
   - **Type:** Percentage discount
   - **Percentage off:** 50%
   - **Duration:** Forever
   - **Name:** "50% Off Lifetime Discount"
4. Click **"Create coupon"**

**Note:** If you create it manually in BOTH test and production modes, the code won't need to create it automatically.

**What happens:**
- Discount applies immediately to active subscriptions
- For trial users, discount applies when trial converts to paid
- Shows on invoices as "50% off"
- Reduces subscription price permanently

---

### 4. **Trial Extensions** 🎁

**What it does:** Extends trial period for trial users

**Configuration:**

✅ **No Stripe Dashboard configuration needed!**

Your code directly updates the `trial_end` timestamp:
```javascript
await stripe.subscriptions.update(subscriptionId, {
  trial_end: newTrialEnd,  // Extended date
  proration_behavior: "none"
});
```

**Requirements:**
- Subscription must have `status: "trialing"`
- Your code checks this automatically

**What happens:**
- Trial end date pushed forward by selected duration
- No charges until new trial end date
- Subscription remains in trial status

---

### 5. **Subscription Cancellation** ❌

**What it does:** Cancels subscription at end of billing period

**Configuration:**

✅ **No Stripe Dashboard configuration needed!**

Your code uses the standard cancellation API:
```javascript
await stripe.subscriptions.update(subscriptionId, {
  cancel_at_period_end: true
});
```

**Settings to Review (Optional):**
1. Go to [Stripe Dashboard → Settings → Billing](https://dashboard.stripe.com/settings/billing)
2. Check **"Subscription cancellations"** settings:
   - **Proration:** Decide if you want to issue credits for unused time (your code doesn't prorate)
   - **End of billing period:** Your code uses this (user keeps access until period ends)

**What happens:**
- Subscription marked for cancellation
- User keeps access until `current_period_end`
- No refunds issued (unless you enable proration)
- Status becomes "canceled" after period ends

---

### 6. **Webhooks** 🔔

**What it does:** Keeps your database in sync with Stripe

**Configuration:**

1. Go to [Stripe Dashboard → Developers → Webhooks](https://dashboard.stripe.com/webhooks)
2. Click **"Add endpoint"**
3. **Endpoint URL:** Your Firebase Function URL
   ```
   https://us-central1-thrift-882cb.cloudfunctions.net/handleStripeWebhook
   ```
4. **Events to listen for:**
   - ✅ `customer.subscription.created`
   - ✅ `customer.subscription.updated`
   - ✅ `customer.subscription.deleted`
   - ✅ `customer.subscription.paused`
   - ✅ `customer.subscription.resumed`
   - ✅ `invoice.payment_succeeded`
   - ✅ `invoice.payment_failed`
   - ✅ `setup_intent.succeeded`
   - ✅ `checkout.session.completed`

5. **Copy webhook signing secret** and add to Firebase Functions secrets

**Why it's important:**
- Updates Firestore when subscriptions change
- Notifies your app of payment failures
- Keeps subscription status in sync
- Handles pause/resume events automatically

---

## 🧪 Testing in Test Mode

### 1. **Use Test API Keys**
Your code automatically detects test vs production based on:
```javascript
const isProduction = customerDoc.data().livemode !== false;
```

### 2. **Test Each Flow**

#### A. Pause Subscription (Paying User)
1. Create a test subscription with a real payment method
2. Wait for trial to convert to active
3. Go to Manage Account → Pause
4. Check Stripe Dashboard → Subscription should show "Paused"
5. Verify `resumes_at` timestamp is set

#### B. Extend Trial (Trial User)
1. Create a test subscription in trial period
2. Go to Manage Account → Extend trial
3. Check Stripe Dashboard → `trial_end` should be extended
4. User should remain in "trialing" status

#### C. Apply Discount
1. Create a test subscription
2. Go to Manage Account → Accept 50% off offer
3. Check Stripe Dashboard → Subscription should show:
   - Coupon: "LIFETIME50"
   - Next invoice reduced by 50%
4. Check Firestore → User document should have `hasLifetimeDiscount: true`

#### D. Cancel Subscription
1. Create a test subscription
2. Go through cancellation flow
3. Check Stripe Dashboard → Should show "Cancels on [date]"
4. Check Firestore → `cancellation_feedback` collection should have entry

### 3. **Test Stripe Cards**
Use these test card numbers:
- **Success:** `4242 4242 4242 4242`
- **Decline:** `4000 0000 0000 0002`
- **3D Secure:** `4000 0027 6000 3184`

---

## 🔍 Debugging with Logs

### Check Firebase Functions Logs
```bash
firebase functions:log --only pauseSubscription,applyLifetimeDiscount,cancelSubscription
```

**Look for:**
```
📥 Cancel subscription request received
   User ID: abc123
✅ User document found
   Stripe Customer ID: cus_xxxxx
   Subscription ID: sub_xxxxx
🔧 Using Stripe TEST mode
✅ Subscription found in Stripe: sub_xxxxx
```

### Check Stripe Dashboard Logs
1. Go to [Stripe Dashboard → Developers → Logs](https://dashboard.stripe.com/logs)
2. Filter by:
   - API calls from your server
   - Webhook events
   - Error responses
3. Look for your subscription ID or customer ID

---

## 🚨 Common Issues & Solutions

### Issue 1: "Subscription not found"
**Cause:** Subscription doesn't exist in Stripe
**Solution:**
- Check if user completed payment
- Verify webhook processed `checkout.session.completed`
- Check `stripe_customers` collection has the subscription ID

### Issue 2: "Cannot pause subscription"
**Cause:** Subscription might not support pausing
**Solution:**
- Verify subscription status is "active" (not "canceled" or "incomplete")
- Check that `pause_collection` feature is available for your plan

### Issue 3: "Coupon already exists"
**Cause:** LIFETIME50 coupon created in different mode (test vs prod)
**Solution:**
- Your code handles this automatically with try/catch
- If error persists, delete and recreate coupon in Stripe Dashboard

### Issue 4: "Cannot extend trial"
**Cause:** Subscription not in trial status
**Solution:**
- Your code checks `status === "trialing"` before extending
- If active subscription, it will pause instead (expected behavior)

---

## 📋 Checklist: What You Need to Do in Stripe

### Essential (Required):
- [ ] Verify API keys are correct in Firebase Functions secrets
- [ ] Set up webhook endpoint with signing secret
- [ ] Test all flows in Test Mode before production

### Optional (Auto-handled by code):
- [ ] Create LIFETIME50 coupon (code creates automatically)
- [ ] Enable subscription pausing (API works without it)
- [ ] Configure cancellation policies (defaults work)

### Recommended:
- [ ] Review subscription settings in Billing settings
- [ ] Set up email notifications for customers (Stripe handles)
- [ ] Configure tax settings if applicable
- [ ] Enable Customer Portal for self-service (optional alternative)

---

## 🎯 Summary

**Good News:** Your backend code is production-ready and handles almost everything automatically!

**Minimum Requirements:**
1. ✅ Valid Stripe API keys in Firebase
2. ✅ Webhook endpoint configured
3. ✅ Test in Test Mode first

**Automatic Features:**
- ✅ Coupon creation (LIFETIME50)
- ✅ Subscription pausing via API
- ✅ Trial extension via API
- ✅ Cancellation via API
- ✅ Error logging and handling

**The manage account flows will work as soon as:**
- Users have valid Stripe subscriptions in your system
- API keys are properly configured
- Webhooks are processing correctly

Your enhanced logging will show exactly what's happening at each step! 🎉

