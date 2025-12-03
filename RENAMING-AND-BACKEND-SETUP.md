# Invoice App - Renaming & Backend Setup Reference

**Last Updated:** November 3, 2025

This document tracks what was renamed and what still needs to be manually configured to fully separate the Invoice app from the old Thrifty app.

---

## ✅ COMPLETED: File & Code Renaming

### Folders Renamed:
- ✅ `Thrifty/` → `Invoice/`
- ✅ `ThriftyTests/` → `InvoiceTests/`
- ✅ `ThriftyUITests/` → `InvoiceUITests/`
- ✅ `Sources/ThriftyServices/` → `Sources/InvoiceServices/`
- ✅ `Tests/ThriftyServicesTests/` → `Tests/InvoiceServicesTests/`

### Swift Files Renamed:
- ✅ `ThriftyApp.swift` → `InvoiceApp.swift`
- ✅ `Thrifty.entitlements` → `Invoice.entitlements`
- ✅ `Thrifty-Info.plist` → `Invoice-Info.plist`
- ✅ All test files renamed
- ✅ All service files renamed

### Code Changes:
- ✅ All struct/class names updated
- ✅ All imports updated
- ✅ All Xcode project references updated
- ✅ All file header comments updated
- ✅ Xcode scheme updated (`Invoice.xcscheme`)
- ✅ All target names updated in Xcode

---

## ⚠️ TODO: Backend Services & Configuration

### 1. **Bundle Identifier** (Critical) ✅ COMPLETED
**Updated to:** `invoice.app`  
**Completed:** November 3, 2025

**What was changed:**
- ✅ Xcode project bundle identifier updated
- ✅ `Invoice-Info.plist` updated
- ✅ Test targets updated (`invoice.app.tests`, `invoice.app.uitests`)
- ✅ Background task identifiers updated

---

### 2. **RevenueCat Subscription IDs**
**Current subscriptions still reference Thrifty:**
```swift
// In ContentView.swift:
"com.thrifty.thrifty.unlimited.yearly149"        // Yearly subscription
"com.thrifty.thrifty.unlimited.yearly.winback79" // Yearly winback offer
"com.thrifty.thrifty.unlimited.monthly"          // Monthly subscription
```

**What to do:**
1. Go to RevenueCat dashboard
2. Create new product IDs for Invoice app:
   - `com.yourcompany.invoice.unlimited.yearly149`
   - `com.yourcompany.invoice.unlimited.yearly.winback79`
   - `com.yourcompany.invoice.unlimited.monthly`
3. Update the subscription IDs in `Invoice/ContentView.swift` (around line 2379-2385)
4. Update RevenueCat API key in backend setup (see below)

**File to update:** `Invoice/ContentView.swift`

---

### 3. **Firebase Configuration** ✅ COMPLETED
**Firebase Project:** `invoice-8b29c`  
**Bundle ID:** `invoice.app`  
**Completed:** November 3, 2025

**What was completed:**
- ✅ New Firebase project created (`invoice-8b29c`)
- ✅ iOS app added with bundle identifier `invoice.app`
- ✅ `GoogleService-Info.plist` replaced and integrated
- ✅ Google Sign-In URL schemes updated in `Invoice-Info.plist`
- ✅ Firebase Authentication enabled (Email/Password, Google, Apple)
- ✅ Cloud Firestore created (nam5 - United States, Production Mode)
- ✅ Cloud Storage created (nam5 - United States)
- ✅ Cloud Messaging enabled

**Security Rules Created:**
- ✅ `firestore.rules` - Secure Firestore rules (on Desktop)
- ✅ `storage.rules` - Secure Storage rules (on Desktop)

**⚠️ REMAINING TASK:** Upload security rules to Firebase:
1. Go to [Firebase Console](https://console.firebase.google.com/project/invoice-8b29c)
2. **Firestore Rules:**
   - Click **Firestore Database** → **Rules** tab
   - Copy contents of `firestore.rules` from Desktop
   - Paste and click **Publish**
3. **Storage Rules:**
   - Click **Storage** → **Rules** tab
   - Copy contents of `storage.rules` from Desktop
   - Paste and click **Publish**

---

### 4. **API Keys** (`Invoice/APIKeys.swift`)
**What to update:**
```swift
struct APIKeys {
    // OpenAI
    static let openAIKey = "YOUR_NEW_OPENAI_KEY"
    
    // Google
    static let googleMaps = "NOT_USED" // Already removed
    static let googleSignInClientID = "FROM_NEW_GoogleService-Info.plist"
    
    // Any other API keys used in your app
}
```

**Note:** Create separate API keys for Invoice app to track usage independently.

---

### 5. **RevenueCat Configuration**
**Current:** `Purchases.configure(withAPIKey: "appl_KKcROFfkXkzRqreINLSiQWOGbvX")`  
(in `Invoice/InvoiceApp.swift`)

**What to do:**
1. Go to [RevenueCat Dashboard](https://app.revenuecat.com/)
2. Create NEW app for Invoice
3. Get new API key
4. Update in `Invoice/InvoiceApp.swift` → `configureRevenueCat()` function
5. Set up new products/subscriptions in App Store Connect
6. Link new products in RevenueCat dashboard

**File to update:** `Invoice/InvoiceApp.swift` (line ~134)

---

### 6. **Mixpanel Configuration**
**Current:** Uses old Thrifty project token

**What to do:**
1. Go to [Mixpanel Dashboard](https://mixpanel.com/)
2. Create NEW project for Invoice app
3. Get new Project Token
4. Update in your Mixpanel service initialization
5. Update any hardcoded event names that reference "Thrifty"

**Files to check:**
- `Invoice/MixpanelService.swift`
- Any analytics tracking code

---

### 7. **Apple Developer Account**
**What to do:**
1. Log into [Apple Developer](https://developer.apple.com/)
2. Create NEW App ID for Invoice with new bundle identifier
3. Configure capabilities (Push Notifications, In-App Purchase, etc.)
4. Create new provisioning profiles
5. Update code signing in Xcode with new profiles

**Xcode:** Signing & Capabilities tab → Select new team/profiles

---

### 8. **App Store Connect**
**What to do:**
1. Log into [App Store Connect](https://appstoreconnect.apple.com/)
2. Create NEW app listing for Invoice
3. Set up In-App Purchases (must match RevenueCat product IDs from step 2)
4. Configure App Store product page
5. Upload new screenshots/metadata
6. Set up TestFlight if needed

**Important:** Use NEW bundle identifier from Step 1

---

### 9. **Stripe Configuration** (if applicable)
**What to do:**
1. Create new Stripe account or new product in existing account
2. Get new API keys (Publishable Key & Secret Key)
3. Update in backend/API code
4. Set up new webhook endpoints
5. Update payment processing code

**Files to check:**
- Backend API configuration
- Any Stripe SDK initialization in Swift code

---

### 10. **Function Environment Files**
**Current:**
- `functions/.env.fye-ai` (old Fye references)
- `functions/.env.thrift-882cb` (old Thrift references)

**What to do:**
1. Create NEW `.env` file: `functions/.env.invoice`
2. Update all environment variables:
   - Firebase credentials
   - API keys
   - Service account keys
   - Webhook URLs
3. Update Cloud Functions deployment configuration
4. Redeploy functions with new environment

**Files to update:**
- `functions/.env.invoice` (create new)
- `functions/package.json` (if environment is referenced)

---

### 11. **Push Notifications**
**What to do:**
1. Generate new APNs certificate/key in Apple Developer
2. Upload to Firebase Console (Cloud Messaging)
3. Update FCM server key if using backend services
4. Test push notifications with new configuration

**Apple Developer:** Certificates, Identifiers & Profiles → Keys → APNs

---

### 12. **Google Sign-In**
**What to do:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create NEW OAuth 2.0 Client ID for Invoice
3. Add new bundle identifier to allowed apps
4. Update URL schemes in Xcode
5. Get new CLIENT_ID from `GoogleService-Info.plist` (from Step 3)

**File to update:** Automatic when you replace `GoogleService-Info.plist`

---

### 13. **Backend API Endpoints**
**What to check:**
If you have any backend services, update:
- Base URLs pointing to Thrifty services
- Authentication tokens
- API keys
- Webhook endpoints
- Database connection strings (if separate database for Invoice)

**Files to check:**
- `Invoice/ConsumptionRequestService.swift`
- `Invoice/RefundRequestService.swift`
- Any networking/API service files

---

### 14. **Firebase Functions**
**What to do:**
1. Review all Cloud Functions in `functions/` directory
2. Update any hardcoded references to "thrifty" or "fye"
3. Update environment variables in functions config
4. Redeploy all functions to new Firebase project
5. Test webhook endpoints

**Files to update:**
- `functions/appleWebhook.js`
- `functions/consumptionService.js`
- Any other function files

---

### 15. **URL Schemes & Deep Links**
**What to do:**
1. Update URL schemes in `Invoice-Info.plist`
2. Update Associated Domains in `Invoice.entitlements`
3. Set up new Universal Links in Apple Developer
4. Update deep link handling code if references "thrifty"

**Files to check:**
- `Invoice-Info.plist` → CFBundleURLSchemes
- `Invoice.entitlements` → Associated Domains

---

### 16. **Third-Party Service Integrations**
**Check if you're using:**
- Analytics services (Amplitude, Segment, etc.)
- Crash reporting (Sentry, Crashlytics)
- Customer support (Intercom, Zendesk)
- Email services (SendGrid, Mailgun)
- SMS services (Twilio)

**What to do:** Create separate accounts/projects for Invoice app to keep data separate.

---

## 📝 Testing Checklist

After making backend changes, test:
- [ ] App launches successfully
- [ ] Authentication (Google Sign-In, Email/Password)
- [ ] Onboarding flow
- [ ] Subscription/paywall functionality
- [ ] RevenueCat purchase flow
- [ ] Push notifications
- [ ] Firebase Firestore read/write
- [ ] Cloud Functions (webhooks)
- [ ] Deep links/Universal Links
- [ ] Analytics events tracking
- [ ] All API calls to backend

---

## 🚨 Critical Notes

1. **DO NOT delete old Thrifty backend services** until Invoice app is fully tested and live
2. **Keep both apps in separate Firebase projects** to avoid data conflicts
3. **Use different RevenueCat projects** to track subscriptions separately
4. **Test with TestFlight** before production release
5. **Update privacy policy/terms** if domain or company changes

---

## 📱 App Store Submission Checklist

Before submitting to App Store:
- [ ] New bundle identifier configured
- [ ] All API keys updated
- [ ] Firebase project set up
- [ ] RevenueCat products live in App Store Connect
- [ ] In-App Purchases tested in Sandbox
- [ ] Push notifications working
- [ ] All backend services deployed
- [ ] Privacy policy updated
- [ ] App icons updated (remove Thrifty branding)
- [ ] Screenshots updated
- [ ] App description/metadata written

---

## 🔗 Quick Links

- [Firebase Console](https://console.firebase.google.com/)
- [RevenueCat Dashboard](https://app.revenuecat.com/)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [Apple Developer](https://developer.apple.com/)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Mixpanel Dashboard](https://mixpanel.com/)

---

**Remember:** This is a comprehensive list. Prioritize Steps 1-8 as they're critical for the app to function properly.

