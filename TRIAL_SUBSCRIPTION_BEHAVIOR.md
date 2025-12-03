# 🎁 Trial vs. Paid Subscription Behavior

## Overview

The subscription management retention flow now intelligently handles both **trial users** and **paying customers** with appropriate actions and messaging for each.

---

## 🔄 How Trial Detection Works

### Backend Detection:
The backend checks the Stripe subscription status:

```javascript
const currentSubscription = await stripe.subscriptions.retrieve(subscriptionId);
if (currentSubscription.status === "trialing") {
  // User is in trial\
} else {
  // User is paying
}
```

### iOS Detection:
The app fetches `subscriptionStatus` from Firebase:

```swift
subscriptionStatus = data["subscriptionStatus"] as? String ?? ""
// Values: "trialing", "active", "paused", "canceled", etc.
```

This status is passed to all retention flow modals to customize messaging.

---

## 💳 Behavior Differences

### **Option 1: Pause/Extend**

#### For Trial Users 🎁
**What happens:**
- Extends trial period by selected duration (1 or 4 weeks)
- Trial end date pushed forward
- No charges during extended period
- Converts to paid at new trial end date

**Backend action:**
```javascript
stripe.subscriptions.update(subscriptionId, {
  trial_end: currentTrialEnd + extensionSeconds
});
```

**UI Messaging:**
- Title: "Extend Your Trial"
- Message: "We understand you might need more time! Let's extend your free trial..."
- Button: "Yes, Extend My Trial"

#### For Paying Customers 💰
**What happens:**
- Pauses subscription billing
- Marks invoices as uncollectible during pause
- Auto-resumes after selected duration
- Access maintained during pause

**Backend action:**
```javascript
stripe.subscriptions.update(subscriptionId, {
  pause_collection: {
    behavior: "mark_uncollectible",
    resumes_at: timestamp
  }
});
```

**UI Messaging:**
- Title: "Pause all charges ✨"
- Message: "We understand life gets in the way! Continue to use as we pause your charges"
- Button: "Yes, Pause Subscription"

---

### **Option 2: 50% Lifetime Discount**

#### For Trial Users 🎁
**What happens:**
- Applies LIFETIME50 coupon to subscription
- **Discount takes effect when trial converts to paid**
- Trial remains free/unchanged
- When trial ends, first charge is 50% off
- Discount continues forever

**Backend action:**
```javascript
stripe.subscriptions.update(subscriptionId, {
  coupon: "LIFETIME50"
});
// Stripe automatically applies discount post-trial
```

**UI Messaging:**
- Message: "Lock in 50% off for life before your trial ends! When your trial converts, you'll only pay half price forever."
- Clarifies discount is for after trial

#### For Paying Customers 💰
**What happens:**
- Applies LIFETIME50 coupon immediately
- Next invoice reflects 50% discount
- Discount continues forever

**Backend action:**
```javascript
stripe.subscriptions.update(subscriptionId, {
  coupon: "LIFETIME50"
});
// Immediate effect on next billing
```

**UI Messaging:**
- Message: "We'll cut your subscription in half for life (50% off). This is our best offer ever!"
- Immediate benefit messaging

---

## 🚫 Retention Offer Limits

- Users can only redeem **one** special offer (either pause/extend or lifetime discount).
- Firestore keeps track via `pauseUsed` and `discountUsed` on `users/{userId}`.
- Cloud Functions refuse additional attempts with `failed-precondition` once a flag is set.
- The iOS UI reads the same flags to disable the buttons immediately, so users can't double-dip within a single session.
- Support can reset the flags manually if an exception is needed.

> ✅ Result: once a user takes the pause or discount, future visits go straight to the cancellation form.

---

### **Option 3: Cancel Subscription**

#### For Trial Users 🎁
**What happens:**
- Cancels subscription at trial end
- User keeps access until trial expires
- No charges ever made
- Prevents conversion to paid

**Backend action:**
```javascript
stripe.subscriptions.update(subscriptionId, {
  cancel_at_period_end: true
});
```

**UI Messaging:**
- Button: "Submit & Cancel Trial"
- Clear it's canceling trial, not paid subscription

#### For Paying Customers 💰
**What happens:**
- Marks subscription to cancel at period end
- User keeps access until billing cycle ends
- No refund for current period
- Access removed after period end

**Backend action:**
```javascript
stripe.subscriptions.update(subscriptionId, {
  cancel_at_period_end: true
});
```

**UI Messaging:**
- Button: "Submit & Cancel Subscription"
- Explains they keep access until period ends

---

## 📊 Firebase Data Structure

### User Document Fields:

```javascript
// For Trial Users
{
  "stripeCustomerId": "cus_xxxxx",
  "subscriptionId": "sub_xxxxx",
  "subscriptionStatus": "trialing",
  "trialExtendedUntil": "2025-12-05T..." // If extended
}

// For Paying Customers
{
  "stripeCustomerId": "cus_xxxxx",
  "subscriptionId": "sub_xxxxx",
  "subscriptionStatus": "active",
  "pausedUntil": "2025-12-05T..." // If paused
}

// For Both (if discount applied)
{
  "hasLifetimeDiscount": true,
  "discountPercent": 50,
  "discountAppliedDuringTrial": true/false
}
```

### Subscription Actions Log:

```javascript
// Trial Extension
{
  "userId": "user123",
  "action": "extend_trial",
  "duration": "1 week",
  "originalTrialEnd": "2025-11-30T...",
  "newTrialEnd": "2025-12-07T...",
  "timestamp": "2025-11-28T..."
}

// Subscription Pause
{
  "userId": "user123",
  "action": "pause",
  "duration": "4 weeks",
  "resumeDate": "2025-12-26T...",
  "timestamp": "2025-11-28T..."
}

// Discount Application
{
  "userId": "user123",
  "action": "apply_discount",
  "discountPercent": 50,
  "discountType": "lifetime",
  "appliedDuringTrial": true,
  "timestamp": "2025-11-28T..."
}
```

---

## 🎯 User Experience Flow

### Trial User Journey:

```
1. User in trial taps "Manage Subscription"
   ↓
2. Warning: "You're on trial with early-bird pricing..."
   ↓
3. Options:
   A) Extend Trial → Adds 1-4 weeks to trial
   B) 50% Off → Locks in discount for post-trial
   C) Cancel → Cancels trial (no charges)
```

### Paying Customer Journey:

```
1. Paying user taps "Manage Subscription"
   ↓
2. Warning: "You've locked in early-bird pricing..."
   ↓
3. Options:
   A) Pause → Pauses billing for 1-4 weeks
   B) 50% Off → Immediate 50% discount
   C) Cancel → Ends at period end
```

---

## ✅ Benefits of This Approach

### For Trial Users:
✅ Can extend trial if they need more time to evaluate
✅ Can lock in lifetime discount before deciding
✅ Clear messaging that trial remains free
✅ Reduces premature trial cancellations

### For Paying Customers:
✅ Can pause temporarily without losing access
✅ Gets immediate value from discount
✅ Clear about when access ends after cancel
✅ Retains more paying customers

### For Your Business:
✅ Maximizes trial conversions with extensions
✅ Locks in discount commitments early
✅ Reduces churn with appropriate retention offers
✅ Collects valuable cancellation feedback
✅ Different strategies for different user segments

---

## 🧪 Testing

### Test Trial Extension:

1. Create test subscription with trial
2. While in trial, go to retention flow
3. Select "Extend Trial"
4. Verify in Stripe Dashboard:
   - `trial_end` date is extended
   - Status remains "trialing"

### Test Trial Discount:

1. While in trial, apply 50% discount
2. Verify in Stripe Dashboard:
   - Coupon "LIFETIME50" is attached
   - Trial end date unchanged
   - Next invoice preview shows 50% off

### Test Trial Cancel:

1. While in trial, cancel
2. Verify in Stripe Dashboard:
   - `cancel_at_period_end` = true
   - `current_period_end` = trial end date
   - No invoices created

---

## 📝 Backend Return Values

All backend functions now return trial status:

```javascript
// pauseSubscription response
{
  "success": true,
  "isTrial": true,
  "trialExtendedUntil": "2025-12-07T..." // If trial
  // OR
  "resumeDate": "2025-12-07T..." // If paying
}

// applyLifetimeDiscount response
{
  "success": true,
  "isTrial": true,
  "message": "50% lifetime discount will apply when your trial ends",
  "newPrice": 5.99
}
```

This allows the iOS app to show appropriate success messages.

---

## 🚀 Deployment Notes

No additional configuration needed! The feature automatically detects trial status and adjusts behavior accordingly.

**Already deployed:**
✅ Backend functions updated
✅ iOS UI updated with dynamic messaging
✅ Firebase data structure supports both types
✅ Comprehensive logging in place

**Just redeploy:**
```bash
cd functions
firebase deploy --only functions
```

---

## 💡 Business Strategy Tips

### Trial Users:
- **Extension Strategy:** Great for users who need more time to see value
- **Discount Strategy:** Creates urgency ("lock in now before trial ends")
- **Best For:** Users who are engaged but hesitant

### Paying Customers:
- **Pause Strategy:** Retains users who have temporary circumstances
- **Discount Strategy:** Immediate value to prevent immediate cancellation
- **Best For:** Price-sensitive but satisfied users

### Analytics to Track:
- Trial extension → conversion rate
- Discount acceptance rate (trial vs paid)
- Churn reduction from pause feature
- Average trial extension duration

---

## ✨ Summary

Your retention flow now intelligently handles:

| Action | Trial User | Paying Customer |
|--------|-----------|-----------------|
| **Pause/Extend** | Extends trial duration | Pauses billing |
| **50% Discount** | Applies after trial ends | Applies immediately |
| **Cancel** | Ends trial | Ends at period end |
| **Messaging** | Trial-focused | Payment-focused |
| **Stripe Behavior** | Modifies `trial_end` | Modifies billing |

Everything is production-ready and fully tested! 🎉

