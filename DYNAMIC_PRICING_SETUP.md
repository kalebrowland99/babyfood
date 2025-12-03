# 🎯 Dynamic Pricing with Firebase Remote Config

## ✅ Setup Complete!

Your app now supports **dynamic pricing** controlled via Firebase Remote Config (Firestore). You can switch between pricing tiers without deploying new code!

---

## 📊 Available Pricing Tiers

### **New Pricing Tier** (Enabled when `9dollarpricing = true`)
- **Main Subscription**: $9.99 with 3-day free trial (or immediate charge if `removetrial = true`)
  - Price ID: `price_1Sa0MTEAO5iISw7SKeYn77np`
- **Winback Offer**: $4.99 with 3-day free trial (or immediate charge if `removetrial = true`)
  - Price ID: `price_1Sa0NTEAO5iISw7Sic1M8dOC`

### **Old Pricing Tier** (Default when `9dollarpricing = false`)
- **Main Subscription**: Old price with 3-day free trial (or immediate charge if `removetrial = true`)
  - Price ID: `price_1ST4z9EAO5iISw7ScXpDLQ0t`
- **Winback Offer**: Old price with 3-day free trial (or immediate charge if `removetrial = true`)
  - Price ID: `price_1ST527EAO5iISw7S0lvuIkDz`

### **Test Mode**
- Uses test price ID for both main and winback:
  - Price ID: `price_1SPpmQEAO5iISw7SKWdV84yy`
  - Trial period also controlled by `removetrial` config

### **Trial Period Control**
- **With Trial** (`removetrial = false`): 3-day free trial, then billing starts
- **No Trial** (`removetrial = true`): Immediate charge at checkout

---

## 🔧 Firebase Console Setup

### Step 1: Access Firestore Database

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **thrift-882cb**
3. Navigate to **Firestore Database** in the left sidebar

### Step 2: Navigate to Configuration Document

1. Find the collection: **`app_config`**
2. Find the document: **`paywall_config`**
3. Click to open/edit it

### Step 3: Add Dynamic Pricing Fields

Add the following fields to the `paywall_config` document:

| Field Name | Type | Default Value | Description |
|------------|------|---------------|-------------|
| `9dollarpricing` | boolean | `false` | Controls which pricing tier to use |
| `newmainpriceid` | string | `price_1Sa0MTEAO5iISw7SKeYn77np` | Price ID for $9.99 main subscription |
| `newwinbackpriceid` | string | `price_1Sa0NTEAO5iISw7Sic1M8dOC` | Price ID for $4.99 winback offer |
| `removetrial` | boolean | `false` | If true, removes 3-day trial from all subscriptions |

### Step 4: Save Configuration

Click **"Update"** or **"Save"** to apply changes.

---

## 🎛️ How to Switch Pricing Tiers

### **To Enable NEW Pricing ($9.99/$4.99):**

1. Go to **Firestore Database** → **`app_config`** → **`paywall_config`**
2. Click **"Edit"** on the document
3. Find the field `9dollarpricing`
4. Change it from `false` to `true`
5. Click **"Update"**

**Result:**
- ✅ Main subscription now costs **$9.99** (3-day trial by default)
- ✅ Winback offer now costs **$4.99** (3-day trial by default)
- ✅ Changes take effect immediately (no app update required)

### **To Remove Trial Period:**

1. Go to **Firestore Database** → **`app_config`** → **`paywall_config`**
2. Click **"Edit"** on the document
3. Find the field `removetrial`
4. Change it from `false` to `true`
5. Click **"Update"**

**Result:**
- ✅ All subscriptions now charge immediately (no trial)
- ✅ Applies to both main and winback offers
- ✅ Works with both pricing tiers

### **To Re-enable Trial Period:**

1. Set `removetrial` back to `false`
2. Click **"Update"**
3. **Done!** 3-day trial is back

### **To Revert to OLD Pricing:**

1. Go to **Firestore Database** → **`app_config`** → **`paywall_config`**
2. Click **"Edit"** on the document
3. Find the field `9dollarpricing`
4. Change it from `true` to `false`
5. Click **"Update"**

**Result:**
- ✅ Pricing reverts to old tier
- ✅ Changes take effect immediately

---

## 📱 How It Works

### **App Side (iOS)**

The `RemoteConfigManager` in your iOS app:
1. Fetches configuration from Firestore on app launch
2. Stores pricing config in memory
3. Updates automatically when config changes
4. Falls back to defaults if Firestore is unavailable

```swift
@Published var use9DollarPricing: Bool = false
@Published var newMainPriceId: String = "price_1Sa0MTEAO5iISw7SKeYn77np"
@Published var newWinbackPriceId: String = "price_1Sa0NTEAO5iISw7Sic1M8dOC"
@Published var removeTrial: Bool = false
```

### **Backend Side (Firebase Functions)**

The Firebase functions (`createStripePaymentSheet` and `getStripeCheckoutUrl`):
1. Read pricing config from Firestore on each payment request
2. Select appropriate price ID based on:
   - Environment (test vs production)
   - Flow type (main vs winback)
   - Pricing tier (`9dollarpricing` flag)
3. Create Stripe checkout session with selected price

```javascript
const use9DollarPricing = config["9dollarpricing"] || false;
const removeTrial = config.removetrial || false;

if (use9DollarPricing) {
  priceId = isWinback 
    ? config.newwinbackpriceid  // $4.99
    : config.newmainpriceid;     // $9.99
} else {
  // Use old pricing
}

// Conditionally add trial
if (!removeTrial) {
  sessionConfig.subscription_data = { trial_period_days: 3 };
}
```

---

## 🔍 Verification & Testing

### **Check Current Configuration**

In Firebase Console → Firestore:
```
app_config/paywall_config
```

Look for:
- ✅ `9dollarpricing`: Should show `true` or `false`
- ✅ `newmainpriceid`: Should show the $9.99 price ID
- ✅ `newwinbackpriceid`: Should show the $4.99 price ID
- ✅ `removetrial`: Should show `true` or `false`

### **Test in Your App**

1. **Enable New Pricing** in Firebase Console
2. **Restart Your App** (or wait ~1 minute for config to refresh)
3. **Initiate a subscription purchase**
4. **Check Firebase Function Logs**:

```bash
firebase functions:log --only createStripePaymentSheet
```

Look for log output:
```
🎯 Using $9 pricing: true
🎯 Remove trial: false
💰 Using $9 pricing tier: $9.99 main
💰 Price ID: price_1Sa0MTEAO5iISw7SKeYn77np
🎁 Including 3-day free trial
```

Or if trial is removed:
```
🎯 Using $9 pricing: true
🎯 Remove trial: true
💰 Using $9 pricing tier: $9.99 main
💰 Price ID: price_1Sa0MTEAO5iISw7SKeYn77np
⚡ No trial - immediate charge
```

### **Monitor Function Logs**

Watch real-time logs while testing:
```bash
firebase functions:log --follow
```

---

## 🚀 Deployment

### **Functions Already Deployed**

Your Firebase functions are already configured to read from Firestore. No redeployment needed!

### **If You Need to Redeploy**

```bash
cd functions
firebase deploy --only functions:createStripePaymentSheet,functions:getStripeCheckoutUrl
```

---

## 🎨 Custom Price IDs (Optional)

### **To Use Different Price IDs:**

1. Create new prices in [Stripe Dashboard](https://dashboard.stripe.com/prices)
2. Ensure they have a **3-day trial period**
3. Copy the price IDs (format: `price_xxxxxx`)
4. Update Firebase config:
   - Go to **Firestore** → **`app_config/paywall_config`**
   - Update `newmainpriceid` with your custom main price ID
   - Update `newwinbackpriceid` with your custom winback price ID
5. Save changes

The app will use your custom price IDs immediately!

---

## ⚠️ Important Notes

### **Trial Period**

All prices should include a **3-day free trial** period:
- Configured in Stripe Dashboard when creating the price
- Alternatively, set in Firebase function: `trial_period_days: 3`

### **Production vs Test Mode**

- **Production**: Uses Stripe live keys and real prices
- **Test**: Uses Stripe test keys and test price ID
- Mode is controlled by `useproductionmode` in same Firestore document

### **Price ID Format**

Stripe price IDs always start with `price_`:
```
price_1Sa0MTEAO5iISw7SKeYn77np  ✅ Correct
prod_abc123                      ❌ Wrong (this is a product ID)
sub_xyz789                       ❌ Wrong (this is a subscription ID)
```

### **Fallback Behavior**

If Firestore is unavailable:
- App uses default values (old pricing)
- Functions use hardcoded fallback price IDs
- Users can still make purchases

---

## 📊 A/B Testing Strategy

### **Recommended Approach**

1. **Start with Old Pricing** (`9dollarpricing = false`)
   - Monitor baseline conversion rate
   - Track 7-day retention

2. **Switch to New Pricing** (`9dollarpricing = true`)
   - Monitor conversion rate changes
   - Compare with baseline metrics
   - Track customer feedback

3. **Toggle Back if Needed**
   - Can revert instantly via Firebase Console
   - No app deployment required

### **Metrics to Track**

- **Conversion Rate**: % of users who subscribe
- **Trial Start Rate**: % of users who start trial
- **Trial-to-Paid**: % of trial users who convert to paid
- **7-Day Retention**: % of users still active after 7 days
- **Revenue per User**: Average revenue across all users

---

## 🐛 Troubleshooting

### **Config Not Loading**

**Symptom**: App still uses old pricing after changing config

**Solutions**:
1. Check Firestore rules allow read access:
   ```javascript
   match /app_config/{document=**} {
     allow read: if true;
   }
   ```
2. Force close and restart app
3. Check app logs for Firestore errors
4. Verify Firebase is initialized before config loads

### **Function Using Wrong Price**

**Symptom**: Firebase function logs show wrong price ID

**Solutions**:
1. Check `9dollarpricing` field in Firestore is correct type (boolean)
2. Verify price IDs are correct strings (no typos)
3. Check function logs for config fetch errors
4. Redeploy functions if code was recently updated

### **"Price not found" Error**

**Symptom**: Stripe returns error that price doesn't exist

**Solutions**:
1. Verify price ID exists in [Stripe Dashboard](https://dashboard.stripe.com/prices)
2. Check you're using correct Stripe account (test vs production)
3. Ensure price is active (not archived) in Stripe
4. Verify price ID format is correct (`price_xxxxxx`)

---

## 📈 Next Steps

1. **Set Initial Configuration**: Start with `9dollarpricing = false`
2. **Monitor Baseline**: Track metrics for 1-2 weeks
3. **Enable New Pricing**: Set `9dollarpricing = true`
4. **Compare Results**: Analyze impact on conversion and revenue
5. **Optimize**: Adjust based on data

---

## 🎉 Summary

✅ **Dynamic pricing fully configured**  
✅ **Switch pricing tiers in seconds via Firebase Console**  
✅ **No app updates required to change prices**  
✅ **Supports A/B testing and optimization**  
✅ **Includes fallback mechanisms for reliability**

**To change pricing right now:**
1. Go to Firebase Console
2. Navigate to Firestore → `app_config/paywall_config`
3. Set `9dollarpricing` to `true`
4. Click Update
5. Done! 🎊

---

## 📞 Questions?

- Check Firebase Function logs: `firebase functions:log --follow`
- Review Stripe Dashboard for price details
- Test in Stripe test mode before going live
- Monitor conversion metrics closely after changes

