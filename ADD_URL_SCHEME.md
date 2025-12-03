# Add URL Scheme for Stripe Deep Linking

## Quick Steps (2 minutes):

### 1. Open Xcode Project
- Open `Thrifty.xcodeproj` in Xcode

### 2. Select Project Target
- In the left sidebar, click on the **Thrifty** project (blue icon)
- Select the **Thrifty** target (under TARGETS)

### 3. Add URL Scheme
- Click the **Info** tab at the top
- Scroll down to **URL Types**
- Click the **+** button to add a new URL Type

### 4. Configure URL Type
Fill in these values:
- **Identifier:** `com.thrifty.thrifty`
- **URL Schemes:** `thriftyapp`
- **Role:** Editor

### 5. Done! ✅

## What This Does:

When a user completes payment on Stripe:
1. ✅ Stripe redirects to: `thriftyapp://subscription-success?session_id=xxx`
2. ✅ iOS opens your app automatically
3. ✅ App handles the URL and grants access
4. ✅ User sees the main app (no website!)

## Test It:

After adding the URL scheme, you can test it from Terminal:
```bash
xcrun simctl openurl booted "thriftyapp://subscription-success?session_id=test123"
```

This should open your app in the simulator and trigger the success handler!

