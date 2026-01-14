# 🔥 Setup Firebase Project: cal-app-f3017

## ⚠️ IMPORTANT: Your Configuration Needs Updating

Your app is currently configured for the wrong Firebase project (`invoice-8b29c`), but you're using **`cal-app-f3017`**. Follow these steps to fix it.

---

## 📋 Step-by-Step Setup for cal-app-f3017

### Step 1: Download New GoogleService-Info.plist

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com/
   - Sign in with your Google account

2. **Select Your Project**
   - Click on project: **`cal-app-f3017`**
   - (If you don't see it, create a new project with this name)

3. **Add iOS App (if not already added)**
   - Click the gear icon ⚙️ next to "Project Overview"
   - Click "Project settings"
   - Scroll down to "Your apps" section
   - If no iOS app exists:
     - Click "Add app" → iOS icon
     - Enter Bundle ID: `invoice.app` (or your actual bundle ID)
     - Enter App nickname: "Invoice" (optional)
     - Click "Register app"
   
4. **Download GoogleService-Info.plist**
   - In Project Settings → Your apps → iOS app
   - Click "Download GoogleService-Info.plist"
   - Save the file

5. **Replace the Old File**
   ```bash
   # Save your new GoogleService-Info.plist to:
   /Users/kaleb/Desktop/invoice/Invoice/GoogleService-Info.plist
   ```
   - In Finder, navigate to: `/Users/kaleb/Desktop/invoice/Invoice/`
   - Delete the old `GoogleService-Info.plist`
   - Drag the new file into that folder
   - In Xcode, make sure it's added to your target

---

### Step 2: Update URL Schemes in Info.plist

After replacing the GoogleService-Info.plist, you need to update the URL scheme for Google Sign-In.

1. **Open the NEW GoogleService-Info.plist** you just downloaded
2. **Find the REVERSED_CLIENT_ID** value (looks like: `com.googleusercontent.apps.XXXXXXX-XXXXXXX`)
3. **Update Info.plist:**

Open `/Users/kaleb/Desktop/invoice/Invoice-Info.plist` and find this section:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>GoogleSignIn</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- REPLACE THIS WITH YOUR NEW REVERSED_CLIENT_ID -->
            <string>com.googleusercontent.apps.477330728361-mniq4fdcdfdt13n7tghcs867kfmld5pt</string>
        </array>
    </dict>
    <!-- ... other URL schemes ... -->
</array>
```

Replace the old REVERSED_CLIENT_ID with the new one from your downloaded file.

4. **Also update GIDClientID:**

Find this in the same file:

```xml
<key>GIDClientID</key>
<string>477330728361-mniq4fdcdfdt13n7tghcs867kfmld5pt.apps.googleusercontent.com</string>
```

Replace with the new CLIENT_ID from your GoogleService-Info.plist.

---

### Step 3: Enable Authentication in Firebase Console

Now enable authentication methods in the **cal-app-f3017** project:

1. **Navigate to Authentication**
   - In Firebase Console, with **cal-app-f3017** selected
   - Click "Authentication" in the left sidebar
   - Click "Get started" (if first time)
   - Click "Sign-in method" tab

2. **Enable Email/Password**
   - Click "Email/Password"
   - Toggle "Enable" to ON
   - Click "Save"

3. **Enable Google Sign-In**
   - Click "Google"
   - Toggle "Enable" to ON
   - Select your support email from dropdown
   - Click "Save"

4. **Enable Apple Sign-In**
   - Click "Apple"
   - Toggle "Enable" to ON
   - Click "Save"

---

### Step 4: Configure Google OAuth (if needed)

Since this is a new Firebase project, you may need to configure Google OAuth:

1. **Get OAuth Client ID from Firebase**
   - In Firebase Console → Authentication → Sign-in method
   - Click on "Google" provider
   - Note the "Web SDK configuration" → Web client ID

2. **Verify in Google Cloud Console**
   - Go to: https://console.cloud.google.com/
   - Select the project associated with `cal-app-f3017`
   - Navigate to: APIs & Services → Credentials
   - You should see OAuth 2.0 Client IDs:
     - Web client (auto created by Firebase)
     - iOS client (create if not exists)

3. **Create iOS OAuth Client (if needed)**
   - Click "Create Credentials" → "OAuth client ID"
   - Select "iOS" as Application type
   - Enter Bundle ID: `invoice.app` (your actual bundle ID)
   - Click "Create"
   - Note the Client ID (this should match what's in GoogleService-Info.plist)

---

### Step 5: Verify Apple Sign-In Configuration

Apple Sign-In should work automatically, but verify:

1. **In Apple Developer Console**
   - Go to: https://developer.apple.com/account/
   - Navigate to: Certificates, Identifiers & Profiles
   - Select your App ID: `invoice.app`
   - Ensure "Sign In with Apple" capability is checked
   - Save if you made changes

2. **In Xcode**
   - Select your project in Xcode
   - Select your target
   - Go to "Signing & Capabilities" tab
   - Verify "Sign In with Apple" capability is present
   - (Already configured in your entitlements file)

---

## ✅ Verification Checklist

After completing all steps:

- [ ] Downloaded new GoogleService-Info.plist from cal-app-f3017 project
- [ ] Replaced old GoogleService-Info.plist in Invoice folder
- [ ] Updated REVERSED_CLIENT_ID in Invoice-Info.plist
- [ ] Updated GIDClientID in Invoice-Info.plist
- [ ] Enabled Email/Password in Firebase Console
- [ ] Enabled Google Sign-In in Firebase Console (with support email)
- [ ] Enabled Apple Sign-In in Firebase Console
- [ ] Verified OAuth credentials in Google Cloud Console
- [ ] Verified Apple Sign-In in Apple Developer Console

---

## 🧪 Test Your Setup

1. **Clean Build**
   ```bash
   # In Xcode
   Product → Clean Build Folder (Cmd + Shift + K)
   ```

2. **Run the App**
   - Build and run your app
   - You should see the login screen

3. **Test Each Method**
   - ✅ **Email/Password**: Sign up with a new account
   - ✅ **Google Sign-In**: Sign in with your Google account
   - ✅ **Apple Sign-In**: Sign in with your Apple ID

4. **Verify in Firebase Console**
   - Go to Authentication → Users
   - You should see the users you created
   - They should appear in the **cal-app-f3017** project

---

## 🔍 What's Different in cal-app-f3017

### Your New Project Configuration:
- **Project ID**: `cal-app-f3017`
- **Project Name**: (Your choice)
- **Bundle ID**: `invoice.app` (or your actual bundle ID)
- **OAuth Client**: New credentials specific to this project
- **Users**: Stored in this project's Firebase Authentication
- **Firestore**: Separate database for this project
- **Storage**: Separate storage bucket

### Important Notes:
- Users from the old `invoice-8b29c` project won't transfer automatically
- You'll need to enable authentication methods in the new project
- All Firebase services (Firestore, Storage, etc.) will use the new project
- Analytics and monitoring will be separate

---

## 🚨 Common Issues

### Issue: "Invalid API key"
**Solution**: Make sure you replaced GoogleService-Info.plist and restarted the app

### Issue: "Google Sign-In not working"
**Solution**: 
- Verify REVERSED_CLIENT_ID is updated in Info.plist
- Check OAuth client is created for iOS in Google Cloud Console

### Issue: "Users not appearing in Firebase Console"
**Solution**: 
- Make sure you're looking at the correct project (cal-app-f3017)
- Check that authentication methods are enabled

### Issue: "Bundle ID mismatch"
**Solution**:
- Ensure Bundle ID in Xcode matches the one registered in Firebase
- Re-download GoogleService-Info.plist if you changed the bundle ID

---

## 📝 Quick Command to Update Files

After downloading your new GoogleService-Info.plist:

```bash
# 1. Replace the file (do this in Finder or with this command)
cp ~/Downloads/GoogleService-Info.plist /Users/kaleb/Desktop/invoice/Invoice/GoogleService-Info.plist

# 2. Clean build in Xcode
# Product → Clean Build Folder (Cmd + Shift + K)

# 3. Rebuild and test
```

---

## 🎯 Summary

**What you need to do:**
1. Download GoogleService-Info.plist from `cal-app-f3017` project
2. Replace the old file in your Invoice folder
3. Update URL schemes in Info.plist with new REVERSED_CLIENT_ID and CLIENT_ID
4. Enable authentication methods in Firebase Console (cal-app-f3017 project)
5. Test all authentication methods

**Time required:** 5-10 minutes

**Once complete:** Your app will be fully connected to the `cal-app-f3017` Firebase project! 🚀

---

Need help with any step? Let me know!
