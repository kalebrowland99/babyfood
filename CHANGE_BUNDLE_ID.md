# 📦 How to Change Bundle ID

## ✅ Yes, You Can Change It!

You can use any bundle ID you want, but it needs to be **consistent** across all platforms.

---

## 🎯 Recommended Bundle ID Format

```
com.yourcompany.appname
```

**Examples:**
- `com.kaleb.calapp`
- `com.yourname.invoice`
- `com.mycompany.calorietracker`
- `invoice.app` (your current one - also valid)

---

## 📋 Step-by-Step: Change Bundle ID

### Step 1: Change in Xcode (1 min)

1. **Open your project in Xcode**
2. **Select the project** in the navigator (top item)
3. **Select your target** ("Invoice")
4. **Go to "General" tab**
5. **Find "Bundle Identifier"** section
6. **Change it** to your new bundle ID
   - Example: `com.kaleb.calapp`

**Screenshot location:** General tab → Identity → Bundle Identifier

---

### Step 2: Register in Firebase Console (2 min)

1. **Go to Firebase Console**
   - https://console.firebase.google.com/
   - Select project: **`cal-app-f3017`**

2. **Go to Project Settings**
   - Click gear icon ⚙️ → "Project settings"

3. **Add or Update iOS App**
   - Scroll to "Your apps" section
   
   **Option A: If no iOS app exists:**
   - Click "Add app" → iOS icon
   - Enter your **new bundle ID**
   - Register app
   - Download GoogleService-Info.plist
   
   **Option B: If iOS app already exists:**
   - You can't change an existing app's bundle ID
   - Either:
     - Delete the old app and create a new one, OR
     - Add a second iOS app with the new bundle ID
   - Download GoogleService-Info.plist for the correct app

---

### Step 3: Replace GoogleService-Info.plist (1 min)

1. **Download the new file** from Firebase (from Step 2)
2. **Open it** and verify the bundle ID is correct:
   ```xml
   <key>BUNDLE_ID</key>
   <string>com.kaleb.calapp</string> <!-- Your new bundle ID -->
   ```
3. **Replace** the old file at:
   `/Users/kaleb/Desktop/invoice/Invoice/GoogleService-Info.plist`

---

### Step 4: Update Apple Developer Console (3 min)

**Only needed if you're using Apple Sign-In (you are)**

1. **Go to Apple Developer Console**
   - https://developer.apple.com/account/
   - Navigate to: Certificates, Identifiers & Profiles → Identifiers

2. **Option A: Update existing App ID**
   - Find your existing App ID: `invoice.app`
   - ⚠️ **You can't change the identifier**, but you can:
     - Use the existing one, OR
     - Create a new one (see Option B)

3. **Option B: Create new App ID** (recommended if changing)
   - Click the "+" button
   - Select "App IDs"
   - Select "App"
   - Fill in:
     - **Description:** "Cal App" (or your app name)
     - **Bundle ID:** Explicit
     - **Bundle ID value:** `com.kaleb.calapp` (your new bundle ID)
   - Scroll down to **Capabilities**
   - Check **"Sign In with Apple"**
   - Click "Continue" → "Register"

4. **Update in Xcode** (if created new App ID)
   - Xcode → Select target → "Signing & Capabilities" tab
   - You may need to re-add "Sign In with Apple" capability
   - Or just clean and rebuild

---

### Step 5: Update Google OAuth (if using Google Sign-In)

**You are using Google Sign-In, so this is important**

1. **Go to Google Cloud Console**
   - https://console.cloud.google.com/
   - Select project linked to `cal-app-f3017`

2. **Navigate to Credentials**
   - APIs & Services → Credentials

3. **Update or Create iOS OAuth Client**
   
   **Option A: Update existing client**
   - Click on your iOS OAuth client
   - Update Bundle ID to your new one
   - Save
   
   **Option B: Create new client** (if no iOS client exists)
   - Click "Create Credentials" → "OAuth client ID"
   - Select "iOS"
   - Enter Bundle ID: `com.kaleb.calapp` (your new bundle ID)
   - Click "Create"
   - Note the Client ID

4. **Important:** The Client ID should match what's in your GoogleService-Info.plist
   - If Firebase created the iOS app correctly, it should auto-create the OAuth client
   - Verify they match

---

### Step 6: Update Info.plist URL Schemes (2 min)

**File:** `/Users/kaleb/Desktop/invoice/Invoice-Info.plist`

The URL schemes are based on your OAuth Client ID, **NOT your bundle ID**.

1. **Open your new GoogleService-Info.plist**
2. **Copy these values:**
   - `REVERSED_CLIENT_ID`
   - `CLIENT_ID`

3. **Update Invoice-Info.plist:**

Find and update:
```xml
<key>CFBundleURLSchemes</key>
<array>
    <!-- Update with REVERSED_CLIENT_ID from GoogleService-Info.plist -->
    <string>com.googleusercontent.apps.XXXXXXX-XXXXXXX</string>
</array>
```

And:
```xml
<key>GIDClientID</key>
<!-- Update with CLIENT_ID from GoogleService-Info.plist -->
<string>XXXXXXX-XXXXXXX.apps.googleusercontent.com</string>
```

---

### Step 7: Clean Build & Test (2 min)

1. **Clean build folder**
   - Xcode: Product → Clean Build Folder (`Cmd + Shift + K`)

2. **Delete app from simulator/device**
   - Long press the app icon → Delete
   - This clears old bundle ID data

3. **Build and run**
   - Run the app
   - Test all authentication methods:
     - ✅ Email/Password
     - ✅ Google Sign-In
     - ✅ Apple Sign-In

4. **Verify in Firebase**
   - Firebase Console → Authentication → Users
   - New users should appear with your new bundle ID

---

## ✅ Verification Checklist

Make sure bundle ID matches in all these places:

- [ ] **Xcode** (Target → General → Bundle Identifier)
- [ ] **GoogleService-Info.plist** (BUNDLE_ID key)
- [ ] **Firebase Console** (iOS app registration)
- [ ] **Apple Developer Console** (App ID identifier)
- [ ] **Google Cloud Console** (OAuth client bundle ID)

---

## 🎯 Quick Decision Guide

### Should I change my bundle ID?

**Change it if:**
- ✅ You want a more professional/branded ID
- ✅ Current ID doesn't match your company/app name
- ✅ You're starting fresh
- ✅ You haven't deployed to App Store yet

**Keep current (`invoice.app`) if:**
- ✅ Already in production/App Store
- ✅ Don't want to reconfigure everything
- ✅ Current ID works fine for you

---

## 💡 Pro Tips

### 1. Use Reverse Domain Notation
```
Good: com.yourcompany.appname
Okay: invoice.app
Avoid: myapp, app123
```

### 2. Keep It Simple
- Lowercase letters
- No special characters (except dots)
- No spaces

### 3. Make It Unique
- Your bundle ID must be globally unique
- Check it doesn't conflict with existing apps

### 4. Consider Your Brand
```
Examples:
com.kaleb.calapp          ← Personal app
com.mycompany.caltracker  ← Company app
com.brandname.invoice     ← Branded app
```

---

## 🔄 Current vs New Bundle ID

### Your Current Setup:
```
Bundle ID: invoice.app
```

### If You Change It:
```
New Bundle ID: com.kaleb.calapp (example)
```

**Everything else stays the same:**
- ✅ App name can stay "Invoice"
- ✅ Display name can be anything
- ✅ Code doesn't need to change
- ✅ Authentication code works the same

---

## 🚨 Important Notes

### 1. **Can't Change After App Store Release**
Once your app is in the App Store, you **can't change the bundle ID**. You'd need to create a completely new app.

### 2. **Keychain Data**
Changing bundle ID means:
- Users will need to log in again
- Keychain data is tied to bundle ID
- Saved data may not transfer

### 3. **In-App Purchases**
If you're using In-App Purchases:
- Products are tied to bundle ID
- You'd need to recreate them in App Store Connect

### 4. **Push Notifications**
If using push notifications:
- APNs certificate is tied to bundle ID
- You'd need to recreate certificates

---

## 📝 Summary

**YES, you can change it**, but do it **before** you:
- Submit to App Store
- Enable In-App Purchases
- Configure Push Notifications
- Have real users

**Best time to change:** NOW (during development)

**Steps:**
1. Change in Xcode
2. Register new bundle ID in Firebase
3. Download new GoogleService-Info.plist
4. Update Apple Developer Console
5. Update Google OAuth
6. Update Info.plist
7. Clean build and test

**Time required:** 10-15 minutes

---

## 🆘 Recommended Decision

**If you're just starting development:** Change it to something like:
```
com.yourname.calapp
```

**If you're far along:** Keep `invoice.app` to avoid reconfiguration hassle.

---

Need help changing it? Let me know what bundle ID you want to use! 🚀
