# 🚀 Adding Facebook SDK to Thrifty - Manual Steps Required

## ✅ Code Changes (DONE)
- ✅ Added `import FBSDKCoreKit` to ThriftyApp.swift
- ✅ Added `configureFacebookSDK()` method
- ✅ Facebook credentials already in APIKeys.swift

## 📱 Step 1: Add Facebook SDK Package (REQUIRED - DO THIS IN XCODE)

### In Xcode:
1. **Open** `Thrifty.xcodeproj` in Xcode
2. **Click** on the project (blue icon) in left sidebar
3. **Select** "Thrifty" target
4. **Click** "Package Dependencies" tab
5. **Click** the **"+"** button
6. **Enter URL:** `https://github.com/facebook/facebook-ios-sdk.git`
7. **Version:** Select "Up to Next Major Version" → **17.0.0**
8. **Click** "Add Package"
9. **Select these products to add:**
   - ✅ FacebookCore
   - ✅ FacebookBasics  
10. **Click** "Add Package"

## 📝 Step 2: Configure Info.plist in Xcode

### In Xcode:
1. **Select** Thrifty target → **Info** tab
2. **Click** the **"+"** next to any row
3. **Add these keys:**

```xml
FacebookAppID: 1313964556984936
FacebookClientToken: 8a0ec108ef6a2b03fda69aa18cb5afa8
FacebookDisplayName: Thrifty
```

4. **Add URL Scheme:**
   - Expand "URL Types" (or add it if not there)
   - Click **"+"** to add new URL Type
   - **URL Schemes:** `fb1313964556984936`
   - **Identifier:** `com.facebook.sdk`
   - **Role:** Editor

5. **Add Query Schemes:**
   - Find or add "LSApplicationQueriesSchemes" (Array)
   - Add these items:
     - `fbapi`
     - `fb-messenger-share-api`
     - `fbauth2`
     - `fbshareextension`

## 🎯 Step 3: Build and Test

### In Xcode:
1. **Product** → **Clean Build Folder** (Cmd+Shift+K)
2. **Product** → **Build** (Cmd+B)
3. **Run** the app (Cmd+R)
4. **Check console** for: "✅ Facebook SDK configured successfully"

## ✅ Expected Console Output:
```
✅ Firebase configured successfully
✅ Facebook SDK configured successfully
📱 FB App ID: 1313964556984936
✅ Google Sign In configured successfully
...
```

## 🔍 After Setup - Verify:
1. Make a test purchase
2. Check Events Manager → Should see event from "Facebook SDK for iOS"
3. Run AEM wizard again → Should now work!

---

**Once done, come back to chat and I'll help verify it's working!**
