# 🔧 Rename Firebase Project Display Name

## Current vs Desired

**Current:** `project-442045211912`  
**Desired:** `Cal AI`

**Note:** The project ID (`442045211912`) is **permanent** and cannot be changed. But you can change the **display name** that users see.

---

## 📋 Steps to Rename

### Step 1: Update Firebase Project Name

1. **Go to Firebase Console**
   - https://console.firebase.google.com/

2. **Select your project:** `project-442045211912`

3. **Click the gear icon ⚙️** (top left) → **"Project settings"**

4. **In the "General" tab:**
   - Find **"Public-facing name"** or **"Project name"**
   - Click the **pencil/edit icon**
   - Change from: `project-442045211912`
   - Change to: `Cal AI`
   - Click **"Save"**

✅ Done! This updates what users see in Google Sign-In screens.

---

### Step 2: Update Google Cloud Console (Optional)

For the Google Sign-In consent screen:

1. **Go to Google Cloud Console**
   - https://console.cloud.google.com/

2. **Select project:** `project-442045211912`

3. **Navigate to:** APIs & Services → **OAuth consent screen**

4. **Edit the consent screen:**
   - **Application name:** Change to `Cal AI`
   - **Application logo:** (Optional) Upload your app icon
   - **Support email:** Your email
   - Click **"Save"**

✅ This updates what users see when signing in with Google!

---

### Step 3: Update Google Sign-In Settings in Firebase

1. **In Firebase Console** (while in your project)

2. **Go to:** Authentication → Sign-in method → **Google**

3. **Update:**
   - **Public-facing name:** `Cal AI`
   - Click **"Save"**

---

## 🎨 Result After Changes

**Before:**
```
Sign in with Google
to continue to project-442045211912
```

**After:**
```
Sign in with Google
to continue to Cal AI
```

---

## ⚠️ Important Notes

### What CAN Be Changed:
- ✅ Display name / Public-facing name
- ✅ OAuth consent screen name
- ✅ App branding

### What CANNOT Be Changed:
- ❌ Project ID (`442045211912`)
- ❌ Project number
- ❌ API credentials (but you can create new ones)

**The project ID is permanent** but users won't see it after you update the display names!

---

## 🧪 How to Verify

After making changes:

1. **Run your app**
2. **Tap "Sign in with Google"**
3. **You should now see:**
   - "Choose an account"
   - "to continue to **Cal AI**" ← Your new name!

---

## 📱 App Display Name (Bonus)

Want to also change the app name shown on the home screen?

### In Xcode:

1. **Select your project** (top of navigator)
2. **Select your target** ("Invoice")
3. **General tab:**
   - Find **"Display Name"**
   - Change from: `Invoice`
   - Change to: `Cal AI`

4. **Or edit Info.plist:**
   - Add/edit key: `CFBundleDisplayName`
   - Value: `Cal AI`

This changes the name shown under your app icon on the home screen!

---

## ✅ Quick Checklist

- [ ] Firebase Console → Project Settings → Change public-facing name to "Cal AI"
- [ ] Google Cloud Console → OAuth consent screen → Change app name to "Cal AI"
- [ ] Firebase → Authentication → Google provider → Update public-facing name
- [ ] (Optional) Xcode → Target → Change Display Name to "Cal AI"
- [ ] Test Google Sign-In to verify new name appears

---

## 🎯 Summary

**Time needed:** 5 minutes

**Steps:**
1. Firebase Console: Update project display name
2. Google Cloud: Update OAuth consent screen
3. Test: Sign in with Google to see new name

**Result:** Users will see "Cal AI" instead of "project-442045211912"

---

**Ready to rename?** Start with Step 1 in Firebase Console! 🚀
