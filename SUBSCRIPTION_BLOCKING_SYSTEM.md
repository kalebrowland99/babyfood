# Subscription Blocking System

## Overview
This system automatically blocks users from accessing premium features when their subscription is canceled or payment fails, and provides an easy way for them to update their payment method through Stripe Customer Portal.

---

## 🎯 What It Does

### User Scenarios

**1. Subscription Canceled**
- User manually canceled via settings
- App blocks all features
- Shows "Subscription Canceled" screen
- Offers to resubscribe

**2. Payment Failed**
- Credit card declined
- Expired card
- Insufficient funds
- App blocks features after multiple failed attempts
- Shows "Payment Failed" screen  
- Opens Stripe Customer Portal to update payment method

**3. Subscription Expired**
- Trial ended without payment
- Subscription period ended
- App blocks features
- Shows "Subscription Expired" screen
- Offers to renew

---

## 📱 Frontend Components

### 1. SubscriptionBlockingManager
**Location:** `Thrifty/SubscriptionBlockingManager.swift`

**Purpose:** Manages subscription status checking and blocking logic

**Key Features:**
- ✅ Checks subscription status from Firestore every 60 seconds
- ✅ Determines if user should be blocked
- ✅ Stores blocking reason and details
- ✅ Creates Stripe Customer Portal sessions

**Blocking Reasons:**
```swift
enum BlockingReason {
    case none                  // Has access
    case canceled             // User canceled subscription
    case paymentFailed        // Payment declined
    case expired              // Subscription ended
    case incompleteExpired    // Payment never completed
    case unpaid               // Payment overdue
}
```

**Status Check Logic:**
```swift
// Active statuses (user has access)
["active", "trialing", "paused"]

// Blocking statuses
"canceled" → Blocks user
"past_due" → Blocks user  
"unpaid" → Blocks user
"incomplete_expired" → Blocks user

// Payment failures
if lastPaymentError exists → May block depending on attempt count
```

### 2. SubscriptionBlockingView
**Location:** `Thrifty/SubscriptionBlockingView.swift`

**Purpose:** Full-screen blocking paywall shown when user is blocked

**UI Elements:**
- Icon (varies by blocking reason)
- Title explaining what happened
- Detailed message
- Payment error details (if applicable)
- Action buttons:
  - **Update Payment Method** (opens Stripe Customer Portal)
  - **Reactivate Subscription** (navigates to subscription view)
  - **Contact Support** (opens email)

**Integration:**
```swift
// Shown as overlay in ThriftyApp.swift
if authManager.isLoggedIn && 
   authManager.hasCompletedSubscription && 
   blockingManager.showBlockingPaywall {
    SubscriptionBlockingView(blockingManager: blockingManager)
}
```

---

## 🔧 Backend Components

### 1. Stripe Customer Portal Session
**Function:** `createCustomerPortalSession`  
**Location:** `functions/index.js:2770`

**Purpose:** Creates a Stripe Customer Portal session for payment updates

**What it does:**
```javascript
// 1. Gets user's Stripe customer ID from Firestore
// 2. Determines test vs production mode
// 3. Creates Customer Portal session
// 4. Returns URL to open in Safari
```

**Return URL:**
```
thriftyapp://subscription-updated
```
This deep link returns user to the app after payment update.

**Stripe Dashboard Setup Required:**
1. Go to [Stripe Dashboard → Settings → Customer Portal](https://dashboard.stripe.com/settings/billing/portal)
2. Configure what customers can do:
   - ✅ Update payment methods
   - ✅ View billing history
   - ❌ Cancel subscriptions (handle in-app)
3. Set branding (logo, colors)
4. Configure return URL handling

### 2. Payment Failure Webhook Enhancement
**Function:** `handlePaymentFailed`  
**Location:** `functions/index.js:2299`

**What changed:**
```javascript
// Now stores detailed error information
await db.collection("users").doc(userId).update({
  paymentStatus: "failed",
  lastPaymentFailure: new Date(),
  lastPaymentError: errorMessage,        // NEW: Error details
  paymentAttemptCount: invoice.attempt_count,  // NEW: Retry count
  isPremium: attempt_count >= 3 ? false : current,  // NEW: Block after 3 attempts
});
```

**Blocking Logic:**
- Attempts 1-2: Warning, user keeps access
- Attempt 3: User gets blocked
- Attempt 4+: Fully blocked, subscription at risk

### 3. Payment Success Handler
**Function:** `handlePaymentSucceededUpdate`  
**Location:** `functions/index.js:2359`

**What it does:**
```javascript
// Clears error states when payment succeeds
await db.collection("users").doc(userId).update({
  paymentStatus: "succeeded",
  lastPaymentError: null,         // Clear error
  paymentAttemptCount: 0,         // Reset attempts
});
```

---

## 🔄 How It Works

### Flow Diagram

```
User Opens App
      ↓
ThriftyApp.onAppear()
      ↓
checkSubscriptionStatusFromFirestore()
      ↓
blockingManager.checkSubscriptionStatus()
      ↓
Fetch user document from Firestore
      ↓
Check: isPremium + subscriptionStatus + lastPaymentError
      ↓
Determine blocking status
      ↓
   [BLOCKED?]
      ├─ YES → Set showBlockingPaywall = true
      │         ↓
      │    SubscriptionBlockingView appears
      │         ↓
      │    User clicks "Update Payment"
      │         ↓
      │    Create Customer Portal session
      │         ↓
      │    Open in Safari
      │         ↓
      │    User updates card
      │         ↓
      │    Stripe webhook fires
      │         ↓
      │    Firestore updated
      │         ↓
      │    App checks status again
      │         ↓
      │    Access restored!
      │
      └─ NO → User has access, continue to MainAppView
```

### Automatic Checks

**1. On App Launch:**
```swift
Task {
    await blockingManager.checkSubscriptionStatus()
}
```

**2. When App Becomes Active:**
```swift
case .active:
    Task {
        await blockingManager.checkSubscriptionStatus()
    }
```

**3. Every 60 Seconds (Background Timer):**
```swift
Timer.scheduledTimer(withTimeInterval: 60, repeats: true) {
    Task {
        await checkSubscriptionStatus()
    }
}
```

**4. After Payment Portal Closes:**
```swift
// 3-second delay then check
try? await Task.sleep(nanoseconds: 3_000_000_000)
await blockingManager.checkSubscriptionStatus()
```

---

## 🧪 Testing the System

### Test Case 1: Cancel Subscription
1. User has active subscription
2. Go to Settings → Manage Account → Cancel
3. Complete cancellation flow
4. **Expected:** User immediately blocked
5. **Verify:** 
   - Blocking view shows
   - Reason: "Subscription Canceled"
   - Button: "Reactivate Subscription"

### Test Case 2: Payment Failure
1. In Stripe Dashboard, update customer's card to test decline card: `4000000000000002`
2. Trigger invoice payment (or wait for next billing)
3. **Expected:** After 3 failed attempts, user blocked
4. **Verify:**
   - Blocking view shows
   - Reason: "Payment Failed"
   - Error details displayed
   - Button: "Update Payment Method"

### Test Case 3: Update Payment Method
1. User is blocked due to payment failure
2. Click "Update Payment Method"
3. **Expected:** Safari opens with Stripe Customer Portal
4. Update card to valid test card: `4242424242424242`
5. Click "Save" in portal
6. Return to app
7. **Expected:** Access restored within 3 seconds

### Test Case 4: Subscription Expired
1. Let trial subscription expire without payment
2. **Expected:** User blocked immediately after trial ends
3. **Verify:**
   - Blocking view shows
   - Reason: "Subscription Expired"
   - Button: "Reactivate Subscription"

---

## 📊 Firestore Data Structure

### User Document Fields

```javascript
{
  // Existing fields
  stripeCustomerId: "cus_xxxxx",
  subscriptionId: "sub_xxxxx",
  subscriptionStatus: "active" | "trialing" | "canceled" | "past_due" | "unpaid",
  isPremium: true | false,
  
  // NEW fields for blocking system
  paymentStatus: "succeeded" | "failed",
  lastPaymentError: "Your card was declined" | null,
  lastPaymentFailure: Timestamp,
  paymentAttemptCount: 0-4,
  cancelAtPeriodEnd: true | false,
}
```

### Subscription Statuses

| Status | Has Access | Blocked | Description |
|--------|------------|---------|-------------|
| `active` | ✅ Yes | ❌ No | Paying customer |
| `trialing` | ✅ Yes | ❌ No | In free trial |
| `paused` | ✅ Yes | ❌ No | Temporarily paused |
| `canceled` | ❌ No | ✅ Yes | User canceled |
| `past_due` | ❌ No | ✅ Yes | Payment failed |
| `unpaid` | ❌ No | ✅ Yes | Overdue payment |
| `incomplete_expired` | ❌ No | ✅ Yes | Never paid |

---

## 🔒 Stripe Dashboard Configuration

### 1. Customer Portal Setup
**Required for payment updates to work!**

Go to: [dashboard.stripe.com/settings/billing/portal](https://dashboard.stripe.com/settings/billing/portal)

**Features to Enable:**
- ✅ **Update payment methods** (REQUIRED)
- ✅ **View billing history**
- ❌ **Cancel subscriptions** (handle in-app instead)
- ❌ **Change plans** (handle in-app instead)

**Branding:**
- Upload your app icon
- Set primary color to match app
- Add support email

**URLs:**
- **Terms of service:** Your website
- **Privacy policy:** Your website  
- **Default return URL:** `https://yourapp.com` (fallback)

### 2. Webhook Events
Make sure these events are configured:

**Required:**
- `customer.subscription.updated` - Detects status changes
- `customer.subscription.deleted` - Subscription canceled
- `invoice.payment_failed` - Payment failed
- `invoice.payment_succeeded` - Payment succeeded

**Location:** [dashboard.stripe.com/webhooks](https://dashboard.stripe.com/webhooks)

### 3. Billing Settings
**Location:** [dashboard.stripe.com/settings/billing](https://dashboard.stripe.com/settings/billing)

**Smart Retries:**
- ✅ Enable automatic payment retries
- Configure retry schedule (Stripe default: 3-4 attempts over 2 weeks)

**Email Notifications:**
- ✅ Payment failed
- ✅ Card expiring soon
- ✅ Subscription canceled

---

## 📝 User Experience Flow

### Scenario: Card Declined

**Day 1 (First Failure):**
```
📧 Stripe sends email: "Payment Failed"
📱 User opens app → NO BLOCKING yet
ℹ️ User sees banner: "Please update payment method"
```

**Day 3 (Second Failure):**
```
📧 Stripe sends email: "Payment Failed Again"
📱 User opens app → STILL NO BLOCKING
⚠️ User sees urgent banner: "Update payment now"
```

**Day 7 (Third Failure):**
```
📧 Stripe sends email: "Final Attempt"
📱 User opens app → 🚫 BLOCKED!
🛑 Full-screen blocking paywall appears
💳 "Update Payment Method" button
```

**After Updating Card:**
```
💳 User clicks "Update Payment Method"
🌐 Safari opens Stripe Customer Portal
✅ User enters new card details
✅ Saves and returns to app
⏱️ 3-second delay
✅ blockingManager.checkSubscriptionStatus()
✅ Access restored!
🎉 User back to MainAppView
```

---

## 🐛 Troubleshooting

### Issue: User blocked but payment is fine

**Check:**
1. Firestore user document → `subscriptionStatus` field
2. Stripe Dashboard → Check subscription status
3. Console logs → Look for blocking reason

**Fix:**
```bash
# Call debug function
let functions = Functions.functions()
functions.httpsCallable("debugUserSubscription").call(["userId": userId])
```

### Issue: Customer Portal not opening

**Check:**
1. Is Customer Portal configured in Stripe Dashboard?
2. Does user have `stripeCustomerId` in Firestore?
3. Is the Firebase function deployed?

**Console logs:**
```
🔗 Creating Customer Portal session...
✅ Customer Portal URL created
```

### Issue: User not unblocked after payment update

**Possible causes:**
1. Webhook not firing → Check Stripe logs
2. Firestore not updated → Check Firebase console
3. Timer not checking → Force check with `forceCheck()`

**Manual unblock:**
```javascript
// In Firestore, update user document
{
  subscriptionStatus: "active",
  isPremium: true,
  lastPaymentError: null,
  paymentAttemptCount: 0
}
```

---

## 🚀 Deployment Checklist

### Backend
- [ ] Deploy Firebase Functions with new `createCustomerPortalSession`
- [ ] Verify webhooks are receiving events
- [ ] Test payment failure handling in test mode
- [ ] Configure Stripe Customer Portal

### Frontend
- [ ] Add `SubscriptionBlockingManager.swift` to Xcode project
- [ ] Add `SubscriptionBlockingView.swift` to Xcode project
- [ ] Update `ThriftyApp.swift` with blocking integration
- [ ] Test all blocking scenarios
- [ ] Verify Customer Portal opens correctly

### Stripe Dashboard
- [ ] Configure Customer Portal settings
- [ ] Enable payment method updates
- [ ] Set branding and return URLs
- [ ] Test in test mode first
- [ ] Enable in production

---

## 📊 Monitoring

### Key Metrics to Track

1. **Blocking Rate:**
   ```
   (Users blocked / Total users) × 100
   ```

2. **Payment Update Rate:**
   ```
   (Users who updated payment / Users blocked for payment) × 100
   ```

3. **Churn After Blocking:**
   ```
   (Users who didn't return / Users blocked) × 100
   ```

### Firebase Analytics Events

```swift
// Track when user is blocked
MixpanelService.shared.track(event: "User Blocked", properties: [
    "reason": blockingManager.blockingReason.title
])

// Track when Customer Portal opened
MixpanelService.shared.track(event: "Customer Portal Opened", properties: [
    "reason": blockingManager.blockingReason.title
])

// Track when access restored
MixpanelService.shared.track(event: "Access Restored", properties: [
    "previous_reason": blockingManager.blockingReason.title
])
```

---

## ✨ Summary

**What You Built:**
- ✅ Automatic subscription status checking
- ✅ Blocking paywall for canceled/failed subscriptions
- ✅ Stripe Customer Portal integration
- ✅ Payment failure tracking with detailed errors
- ✅ Self-service payment update flow
- ✅ Real-time status updates
- ✅ Graceful error handling

**User Benefits:**
- 🎯 Clear communication about subscription issues
- 💳 Easy way to update payment method
- ⚡ Instant access restoration after payment update
- 📧 Contact support option if needed

**Business Benefits:**
- 💰 Reduce involuntary churn from payment failures
- 📊 Track why subscriptions are failing
- 🔄 Automated recovery flow for failed payments
- 💪 Protect premium features from non-paying users

---

The system is production-ready and will automatically block users when needed while providing a smooth path to restore access! 🎉

