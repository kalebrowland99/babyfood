# 🔧 Cancel Subscription Feature Setup

## Overview

The "Manage Account" feature with subscription retention flow is now controlled by Firebase Remote Config. This allows you to enable/disable the cancel subscription option remotely without updating the app.

## 🎯 How It Works

### Conditions for Showing "Manage Account":
1. ✅ User must have a **Stripe subscription** (not Apple IAP)
2. ✅ Firebase Remote Config `cancelsubscription` must be set to `true`

If either condition is false:
- "Manage Account" section is hidden
- "Delete Account" button appears directly in the menu (not nested)

---

## 🔧 Firebase Setup

### Step 1: Access Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **`thrifty`**
3. Navigate to **Firestore Database** in the left sidebar

### Step 2: Update Configuration Document
1. Go to **`app_config`** collection → **`paywall_config`** document
2. Click **"Edit"** on the document
3. Add the new field:

| Field | Type | Value | Description |
|-------|------|-------|-------------|
| `cancelsubscription` | boolean | `false` | Controls visibility of cancel subscription option |

### Step 3: Set Initial Value

**To HIDE the cancel subscription option (recommended for launch):**
```json
{
  "cancelsubscription": false
}
```

**To SHOW the cancel subscription option:**
```json
{
  "cancelsubscription": true
}
```

---

## 🎛️ How to Enable/Disable Cancel Subscription

### To Enable Cancel Subscription Feature:
1. Go to **Firestore Database** → **`app_config`** → **`paywall_config`**
2. Click **"Edit"** on the document
3. Change `cancelsubscription` from `false` to `true`
4. Click **"Update"**
5. The change takes effect immediately for new app sessions

### To Disable Cancel Subscription Feature:
1. Go to **Firestore Database** → **`app_config`** → **`paywall_config`**
2. Click **"Edit"** on the document
3. Change `cancelsubscription` from `true` to `false`
4. Click **"Update"**

---

## 📱 User Experience

### When ENABLED (`cancelsubscription: true`) AND User Has Stripe Subscription:
1. User sees "Manage Account" option in profile menu
2. Tapping "Manage Account" expands to show:
   - **Manage Subscription** (triggers retention flow)
   - **Delete Account** (nested inside)

### Subscription Retention Flow:
When user taps "Manage Subscription":

**Step 1: Early Bird Warning** 🟠
- Warns about losing early-bird pricing
- Options: "Yes, Continue" or "No, Keep My Pricing"

**Step 2: Pause Subscription** 🔵
- Offers to pause instead of cancel
- Dropdown: 1 week or 4 weeks
- Options: "Yes, Pause Subscription" or "No, I Want to Cancel"

**Step 3: 50% Off for Life** 🟢
- Last retention attempt with lifetime discount
- Options: "Yes, Give Me 50% Off!" or "No, I Still Want to Cancel"

**Step 4: Cancellation Feedback** 🔴
- Text area for user to explain why they're canceling
- Submit button to finalize cancellation

### When DISABLED (`cancelsubscription: false`) OR User Has Apple IAP:
1. "Manage Account" section is hidden
2. "Delete Account" appears directly in the menu (not nested)
3. No subscription retention flow available

---

## 🔍 How Detection Works

### Stripe Subscription Detection:
The app checks Firestore for the user's subscription data:
```swift
// Checks if user document contains stripeCustomerId
db.collection("users").document(userId).getDocument()
```

**User has Stripe subscription if:**
- `stripeCustomerId` field exists in their user document
- Field is not empty

**User has Apple IAP if:**
- No `stripeCustomerId` field
- Or field is empty

### Remote Config Check:
```swift
RemoteConfigManager.shared.cancelSubscription
```
- Loaded from Firestore on app launch
- Cached locally during session
- Refreshed on each app restart

---

## 🧪 Testing

### Test 1: Hide for All Users
```json
{
  "cancelsubscription": false
}
```
**Expected:** "Manage Account" hidden, "Delete Account" shows directly

### Test 2: Show for Stripe Users Only
```json
{
  "cancelsubscription": true
}
```
**Expected:** 
- Users with Stripe subscription see "Manage Account"
- Users with Apple IAP see "Delete Account" directly

### Test 3: Verify Retention Flow
1. Set `cancelsubscription: true`
2. Ensure you have a Stripe subscription
3. Tap "Manage Account" → "Manage Subscription"
4. Verify all 4 steps of retention flow appear correctly

---

## 📊 Complete Firebase Document Structure

Your `app_config/paywall_config` document should look like this:

```json
{
  "hardpaywall": true,
  "stripepaywall": false,
  "usestripesheet": false,
  "useproductionmode": true,
  "cancelsubscription": false,
  "stripecheckouturl": "https://buy.stripe.com/...",
  "stripecheckouturltest": "https://buy.stripe.com/test_...",
  "winbackcheckouturl": "https://buy.stripe.com/...",
  "winbackcheckouturltest": "https://buy.stripe.com/test_...",
  "stripebuttontext": "Try free for 1 month",
  "stripedisclaimertext": "Your disclaimer text...",
  "winbackdisclaimertext": "Winback offer disclaimer...",
  "termsurl": "https://thrifty.com/terms",
  "updatedAt": "serverTimestamp()"
}
```

---

## 🚀 Rollout Strategy

### Recommended Approach:
1. **Launch with feature DISABLED:**
   - Set `cancelsubscription: false`
   - Monitor subscription retention naturally
   
2. **Gradual Rollout:**
   - Enable for beta testers first
   - Monitor retention flow metrics
   - Gather feedback on messaging
   
3. **Full Rollout:**
   - Set `cancelsubscription: true` for all users
   - Monitor cancellation reasons
   - Adjust offers based on feedback

---

## 💡 Implementation Notes

### For Stripe Subscriptions:
- Retention flow is fully implemented
- All 4 steps have proper UI and messaging
- Print statements for debugging each step
- Backend integration needed for:
  - Actual pause functionality
  - 50% discount application
  - Cancellation reason storage

### For Apple IAP Subscriptions:
- Users manage subscriptions through App Store Settings
- No in-app cancellation flow needed
- Apple handles all subscription management

---

## 🔒 Security Notes

- Remote config is read-only for users
- Changes take effect on next app launch
- No app update required to change setting
- Stripe subscription check uses authenticated Firestore queries
- Only shows for users with actual Stripe subscriptions

---

## 📝 Logs to Monitor

When feature is enabled, look for these logs:

```
✅ Config loaded from Firestore - cancelSubscription: true
✅ User has Stripe subscription: cus_xxxxx
🔍 Manage Account section visible
```

When feature is disabled or user has IAP:

```
✅ Config loaded from Firestore - cancelSubscription: false
ℹ️ User does not have Stripe subscription
🔍 Manage Account section hidden, showing Delete Account directly
```

---

## 🆘 Troubleshooting

### "Manage Account" not showing for Stripe user:
1. Check `cancelsubscription` is `true` in Firebase
2. Verify user has `stripeCustomerId` in Firestore
3. Force quit and restart app to refresh config

### Feature showing for Apple IAP user:
1. Verify user document doesn't have `stripeCustomerId`
2. Check Firestore rules allow read access
3. Review app logs for Stripe subscription check

### Config not updating:
1. Force quit app completely
2. Relaunch to trigger config reload
3. Check Firebase Console for correct field name: `cancelsubscription` (lowercase, no spaces)

---

## ✅ Checklist

Before enabling in production:

- [ ] `cancelsubscription` field added to Firebase
- [ ] Tested with Stripe subscription user
- [ ] Tested with Apple IAP user
- [ ] Tested with no subscription
- [ ] All 4 retention flow steps working
- [ ] Backend endpoints ready for pause/discount/cancellation
- [ ] Analytics tracking implemented
- [ ] Customer support team briefed on new flow

