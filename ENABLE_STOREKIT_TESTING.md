# ⚡ Enable StoreKit Testing - Quick Guide

## 🎯 How to Enable Test Subscriptions (2 minutes)

### Step-by-Step with Screenshots:

#### 1. Click on Your Scheme

**Location:** Top of Xcode window, left side, next to the Play/Stop buttons

```
┌─────────────────────────────────┐
│ Invoice > iPhone 15 Pro    ▶ ◼  │  ← Click "Invoice" here
└─────────────────────────────────┘
```

Click on **"Invoice"** (or your scheme name)

---

#### 2. Select "Edit Scheme..."

A dropdown menu will appear:
- ✅ Select **"Edit Scheme..."**

---

#### 3. Configure StoreKit

The Scheme editor window will open:

**Left Sidebar:**
- Click on **"Run"** (should already be selected)

**Top Tabs:**
- Click on **"Options"** tab

**In the Options section:**
1. Find **"StoreKit Configuration"** dropdown
2. Click the dropdown
3. Select **"Subscriptions.storekit"**

```
┌──────────────────────────────────┐
│ StoreKit Configuration:          │
│ ┌──────────────────────────────┐ │
│ │ Subscriptions.storekit    ▼  │ │  ← Select this
│ └──────────────────────────────┘ │
└──────────────────────────────────┘
```

4. Click **"Close"** button

---

#### 4. That's It! ✅

Now when you run your app:
- Subscriptions will use test mode
- No real money involved
- Instant purchase completion
- You can test all subscription features

---

## 🧪 How to Test

### 1. Run Your App

Press **▶ (Play)** button or `Cmd + R`

### 2. Navigate to Subscription Purchase

(Wherever subscriptions are offered in your app)

### 3. Try to Purchase

- The system will show a test purchase dialog
- Click "Subscribe" or "Buy"
- Purchase completes instantly
- No actual money charged

---

## 🎛️ Manage Test Subscriptions

### During Testing:

1. **While app is running**, go to Xcode menu:
   - **Debug** → **StoreKit** → **Manage Transactions**

2. **You can:**
   - View all test purchases
   - Cancel subscriptions
   - Refund purchases
   - Clear all transactions
   - Approve/reject pending transactions

### Speed Up Time (Test Renewals Faster):

1. **Debug** → **StoreKit** → **Time Rate**
2. Select time multiplier:
   - 1 second = 1 minute
   - 1 second = 1 hour
   - 1 second = 1 day

This makes subscriptions renew faster for testing!

---

## 🔍 View Current Configuration

### Check What Products Are Available:

Your `Subscriptions.storekit` file has:

**Subscription Group:** "Thrifty Premium"

| Product | Price | Period | Free Trial |
|---------|-------|--------|------------|
| Monthly Standard | $29.99 | 1 month | 3 days |
| Monthly Winback | $19.99 | 1 month | 3 days |
| Yearly Standard | $149.99 | 1 year | 3 days |
| Yearly Winback | $79.99 | 1 year | 3 days |

---

## ✅ Verification

### How to Know It's Working:

1. **Run the app**
2. **Try to purchase a subscription**
3. **You should see:**
   - "Test" or "Sandbox" badge on purchase dialog
   - Instant completion
   - No actual App Store prompt
   - No payment method required

### If You See Real App Store:

- StoreKit configuration is not enabled
- Go back and verify Step 3
- Make sure "Subscriptions.storekit" is selected
- Close and reopen the scheme editor

---

## 🎨 Optional: Update Subscription Names

Your subscriptions currently say "Thrifty". Want to update them?

### Quick Update:

1. **Open** `Subscriptions.storekit` in Xcode
2. **Click on a subscription** in the file
3. **Update in the inspector** (right sidebar):
   - Display Name
   - Description
   - Reference Name (internal only)
4. **Save** the file

**Want me to update them for you?** Let me know what names you'd like!

---

## 📊 Testing Checklist

Before moving to production:

- [ ] StoreKit configuration enabled
- [ ] All subscription products load
- [ ] Can purchase subscription
- [ ] Free trial works correctly
- [ ] Features unlock after purchase
- [ ] Subscription status displays correctly
- [ ] Can cancel subscription
- [ ] Features lock after cancellation
- [ ] Can restore purchases
- [ ] Subscription renews correctly (use time rate)
- [ ] Billing issues handled gracefully
- [ ] Network errors handled properly

---

## 🚨 Important Notes

### StoreKit Testing vs Production:

**StoreKit Configuration (Testing):**
- ✅ No real money
- ✅ Instant purchases
- ✅ Full control over subscriptions
- ✅ Speed up time
- ❌ Not real App Store

**Production (Live App):**
- Real App Store
- Real money
- Real payment methods
- Normal time scale
- Must be set up in App Store Connect

### When to Use Each:

- **Development:** Use StoreKit Configuration
- **Beta Testing:** Use Sandbox accounts
- **Production:** Remove StoreKit Configuration

---

## 🎯 Quick Summary

**To enable testing:**
1. Scheme → Edit Scheme
2. Run → Options
3. StoreKit Configuration → Subscriptions.storekit
4. Close

**To test:**
1. Run app
2. Try to purchase
3. Enjoy instant test purchases!

**To manage:**
- Debug → StoreKit → Manage Transactions

---

**That's it!** You're ready to test subscriptions! 🚀

**Time to enable:** 2 minutes  
**Ready to test:** Immediately

---

Need help? Let me know! 🎉
