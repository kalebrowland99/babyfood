# 🍎 Apple Subscription Testing Guide

## ✅ What You Already Have

You have a **StoreKit Configuration file** set up with subscriptions:

**Subscription Group:** "Thrifty Premium"

**Products:**
1. **Monthly Subscription** - $29.99/month
   - Product ID: `com.thrifty.thrifty.unlimited.monthly`
   - 3-day free trial

2. **Monthly Winback** - $19.99/month
   - Product ID: `com.thrifty.thrifty.unlimited.monthly.winback`
   - Special offer pricing

3. **Yearly Subscription** - $149.99/year
   - Product ID: `com.thrifty.thrifty.unlimited.yearly149`
   - 3-day free trial

4. **Yearly Winback** - $79.99/year
   - Product ID: `com.thrifty.thrifty.unlimited.yearly.winback79`
   - Special offer pricing

---

## 🎯 How to Test Subscriptions in Xcode

### Method 1: Using StoreKit Configuration (Fastest - No Real Money)

#### Step 1: Enable StoreKit Configuration

1. **Open your project in Xcode**
2. **Click on your scheme** (next to the play button at the top)
3. Select **"Edit Scheme..."**
4. In the left sidebar, select **"Run"**
5. Go to the **"Options"** tab
6. Under **"StoreKit Configuration"**, select:
   - `Subscriptions.storekit`
7. Click **"Close"**

#### Step 2: Run and Test

1. **Run your app** in the simulator or device
2. When you try to purchase a subscription:
   - It will use the test configuration
   - No real money involved
   - Instant purchase approval
   - You can test subscriptions, renewals, cancellations

#### Step 3: Manage Test Subscriptions

**During testing, you can:**
- View active subscriptions
- Cancel subscriptions
- Test renewal
- Test refunds
- Speed up time (make subscriptions renew faster)

**To manage:**
- While app is running in simulator
- Go to: **Debug** menu → **StoreKit** → **Manage Transactions**

---

### Method 2: Sandbox Testing (More Realistic)

#### Create Sandbox Test Accounts

1. **Go to App Store Connect**
   - https://appstoreconnect.apple.com/

2. **Navigate to Users and Access**
   - Click "Users and Access" in the top menu
   - Click "Sandbox" tab
   - Click "+" to add a tester

3. **Create Test Account**
   - Fill in test user details:
     - First Name: Test
     - Last Name: User
     - Email: Use a unique email (can be fake)
     - Password: Create a password
     - Country: United States
   - Click "Invite"

4. **Sign Out of App Store on Device**
   - Settings → App Store → Sign Out

5. **Run App and Test Purchase**
   - Try to make a purchase
   - Sign in with your sandbox account
   - Test the subscription flow

**Benefits:**
- More realistic testing
- Tests actual App Store flow
- Good for final testing before release

---

## 🚀 Quick Setup for Testing (Recommended)

### Option A: Test with StoreKit Configuration (Start Here)

**5-Minute Setup:**

1. **Enable StoreKit in Xcode**
   - Edit Scheme → Run → Options
   - Set StoreKit Configuration to `Subscriptions.storekit`

2. **Run the app**

3. **Test a purchase**
   - Subscriptions will complete instantly
   - No real money involved
   - Perfect for development

4. **Manage test subscriptions**
   - Debug → StoreKit → Manage Transactions
   - You can cancel, refund, etc.

---

## 🎨 Update Branding from "Thrifty" to Your App Name

Your current subscriptions say "Thrifty". Let's update them for your Cal app:

Would you like me to:
1. Update the subscription names from "Thrifty" to "Cal Premium" or "Cal AI"?
2. Adjust pricing if needed?
3. Add different subscription tiers?

---

## 📱 Testing Subscription Features

### Test Free Trial

1. **Purchase a subscription** with free trial
2. **Verify free trial starts**
3. **Check subscription status**
4. **Test cancellation during trial**

### Test Subscription Renewal

With StoreKit Configuration:
- Debug → StoreKit → Time Rate
- Speed up time to test renewals faster

### Test Subscription Cancellation

1. **Purchase subscription**
2. **Debug → StoreKit → Manage Transactions**
3. **Select subscription → Refund/Cancel**
4. **Verify app handles cancellation**

### Test Upgrade/Downgrade

1. **Purchase monthly subscription**
2. **Try to purchase yearly**
3. **Verify upgrade flow**

---

## 🔧 StoreKit Configuration Features

### Speed Up Time for Testing

**Normal:**
- 1 month subscription = 1 month wait

**With Time Rate:**
- Debug → StoreKit → Time Rate → 1 minute = 1 hour
- 1 month subscription renews in ~12 minutes
- Perfect for testing renewals quickly!

### Test Different Scenarios

- ✅ Successful purchase
- ✅ Failed purchase
- ✅ Cancelled subscription
- ✅ Expired subscription
- ✅ Billing issues
- ✅ Refunds

**Enable in:** Debug → StoreKit → Enable Billing Issues / Failed Transactions

---

## 💡 Best Practices for Subscription Testing

### 1. Test All Flows
- [ ] First-time purchase
- [ ] Free trial activation
- [ ] Subscription renewal
- [ ] Subscription cancellation
- [ ] Resubscription after cancellation
- [ ] Upgrade from monthly to yearly
- [ ] Downgrade from yearly to monthly
- [ ] Expired subscription
- [ ] Restore purchases

### 2. Test Error Cases
- [ ] Payment failed
- [ ] Network error during purchase
- [ ] Cancelled transaction
- [ ] Invalid product ID

### 3. Test UI
- [ ] Subscription screen displays correctly
- [ ] Pricing shows correctly
- [ ] Free trial text is clear
- [ ] Subscription status updates in real-time
- [ ] Cancel/manage options work

---

## 🎯 Integration with Your Auth System

Since you now have authentication, you should:

### Link Subscriptions to User Accounts

```swift
// When user purchases subscription
let userID = authManager.user?.uid
// Store subscription status with user ID in Firestore

// On app launch
if let userID = authManager.user?.uid {
    // Check subscription status for this user
}
```

### Store Subscription Status in Firestore

**Recommended structure:**
```
users/{userID}/
  ├── subscription/
      ├── isActive: bool
      ├── productID: string
      ├── expiryDate: timestamp
      ├── autoRenewing: bool
      └── purchaseDate: timestamp
```

---

## 📋 Quick Test Checklist

- [ ] StoreKit configuration enabled in scheme
- [ ] App runs without errors
- [ ] Subscription products load correctly
- [ ] Can initiate purchase
- [ ] Purchase completes successfully
- [ ] Subscription status updates
- [ ] Can access premium features
- [ ] Can cancel subscription
- [ ] Features lock after cancellation
- [ ] Can restore purchases

---

## 🆘 Common Issues

### Issue: "No products available"
**Solution:** 
- Check StoreKit configuration is selected in scheme
- Verify product IDs match exactly in code and .storekit file

### Issue: "Purchase fails immediately"
**Solution:**
- Check for StoreKit errors in Debug menu
- Verify StoreKit configuration is valid

### Issue: "Subscription doesn't unlock features"
**Solution:**
- Verify transaction processing code
- Check subscription status update logic

---

## 🎁 Recommended Subscription Pricing (For Cal App)

Based on typical nutrition/fitness apps:

### Suggested Tiers:

**Monthly:**
- $9.99/month - Standard pricing
- 3-7 day free trial

**Yearly:**
- $49.99/year - Save 50%+ (most popular)
- 7-14 day free trial

**Lifetime (optional):**
- $99.99 - One-time purchase

---

## 🚀 Next Steps

1. **Test with StoreKit Configuration** (5 min)
   - Enable in scheme
   - Run and test purchase

2. **Update Branding** (if needed)
   - Change "Thrifty" to your app name

3. **Integrate with Auth**
   - Link subscriptions to user accounts

4. **Create Subscription UI**
   - Paywall screen
   - Subscription management

5. **Test Thoroughly**
   - All purchase flows
   - Error cases
   - UI/UX

---

**Ready to test?** Just enable the StoreKit configuration in your scheme and run the app! Let me know if you want me to update the subscription names/pricing! 🚀
