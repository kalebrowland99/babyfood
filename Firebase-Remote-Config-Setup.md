# 🔥 Firebase Remote Config Setup for Paywall Control

## 🎯 **What We've Implemented**

Your app now uses **Firebase Firestore** to control paywall behavior remotely. You can switch between **Hard Paywall** and **Soft Paywall** modes directly from Firebase Console without updating your app!

## 📱 **How It Works**

### **Hard Paywall** (`hardpaywall = true`)
- User sees winback screen when they cancel the $29.99 subscription
- Standard paywall behavior

### **Soft Paywall** (`hardpaywall = false`) 
- User automatically gets redirected to main app when they cancel
- No winback screen shown

## 🔧 **Setup Instructions**

### **Step 1: Access Firebase Console**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **`thrifty`**
3. Navigate to **Firestore Database** in the left sidebar

### **Step 2: Create the Configuration Collection**
1. Click **"Start collection"** (if you don't have any collections)
2. **Collection ID**: `app_config`
3. Click **"Next"**

### **Step 3: Create the Paywall Configuration Document**
1. **Document ID**: `paywall_config`
2. Add the following fields:

| Field | Type | Value | Description |
|-------|------|-------|-------------|
| `hardpaywall` | boolean | `true` | Controls paywall mode |
| `updatedAt` | timestamp | `serverTimestamp()` | Tracks when config was last updated |

### **Step 4: Set Initial Configuration**
Click **"Auto-ID"** for the document ID, then add:

```json
{
  "hardpaywall": true,
  "updatedAt": "serverTimestamp()"
}
```

Click **"Save"**

## 🎛️ **How to Switch Paywall Modes**

### **To Enable Soft Paywall (Auto-redirect):**
1. Go to **Firestore Database** → **`app_config`** → **`paywall_config`**
2. Click **"Edit"** on the document
3. Change `hardpaywall` from `true` to `false`
4. Click **"Update"**

### **To Enable Hard Paywall (Show winback):**
1. Go to **Firestore Database** → **`app_config`** → **`paywall_config`**
2. Click **"Edit"** on the document
3. Change `hardpaywall` from `false` to `true`
4. Click **"Update"**

## 🔄 **How the App Reads the Configuration**

The app automatically:
1. **Loads** the configuration when it starts
2. **Checks** the `hardpaywall` value before showing paywall
3. **Updates** behavior immediately when you change the value in Firebase

## 📊 **Firestore Security Rules**

Your current rules already allow this configuration. The app uses the following collection:
- **Collection**: `app_config`
- **Document**: `paywall_config`
- **Access**: Read-only for authenticated users

## 🚀 **Testing the Configuration**

### **Test Hard Paywall:**
1. Set `hardpaywall = true` in Firebase
2. Run your app
3. Try to cancel the $29.99 subscription
4. **Expected**: Winback screen appears

### **Test Soft Paywall:**
1. Set `hardpaywall = false` in Firebase
2. Run your app
3. Try to cancel the $29.99 subscription
4. **Expected**: User automatically goes to main app

## 🔍 **Monitoring Changes**

### **In Firebase Console:**
- Go to **Firestore Database** → **`app_config`** → **`paywall_config`**
- The `updatedAt` field shows when you last changed the configuration

### **In Your App:**
- Check the Xcode console for logs like:
  - `✅ Config loaded from Firestore - hardPaywall: true`
  - `🎛️ Paywall mode set to: HARD`

## 🛠️ **Advanced Configuration**

### **Add More Remote Config Options:**
You can easily add more configuration options by:

1. **Adding new fields** to the `paywall_config` document:
   ```json
   {
     "hardpaywall": true,
     "showSpecialOffer": false,
     "subscriptionPrice": 29.99,
     "updatedAt": "serverTimestamp()"
   }
   ```

2. **Updating the RemoteConfigManager** in your code to read these new values

### **Multiple Environment Support:**
Create different documents for different environments:
- `paywall_config_production`
- `paywall_config_staging`
- `paywall_config_development`

## 🔒 **Security Considerations**

- ✅ Configuration is read-only for users
- ✅ Only you can modify the configuration in Firebase Console
- ✅ Changes take effect immediately
- ✅ No app update required

## 📱 **App Behavior Summary**

| Configuration | User Cancels $29.99 | Result |
|---------------|-------------------|---------|
| `hardpaywall: true` | ❌ | Shows winback screen |
| `hardpaywall: false` | ❌ | Auto-redirects to main app |

## 🎉 **You're All Set!**

Your app now has **remote paywall control** through Firebase! You can switch between hard and soft paywall modes instantly from the Firebase Console without any app updates.

**Next time you want to change the paywall behavior, just update the `hardpaywall` value in Firebase!** 🚀 