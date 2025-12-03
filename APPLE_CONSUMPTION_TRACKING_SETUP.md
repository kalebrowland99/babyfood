# Apple Consumption Tracking Integration Guide

## Overview
This guide will help you integrate Apple's consumption tracking system into your Thrifty iOS app to defend against unfair refunds. The system tracks user engagement and sends consumption data to Apple when refund requests are made.

## Your App Configuration
- **Bundle ID**: `com.thrifty.thrifty`
- **App Store ID**: `[YOUR_APP_STORE_ID]` (Replace with actual ID)
- **Uses RevenueCat**: Yes (detected)
- **Main App File**: `ThriftyApp.swift`

## ✅ Completed Integration Steps

### 1. iOS Integration ✅
- ✅ Updated bundle IDs in Firebase Functions
- ✅ Integrated `TransactionUsageTracker` into `ThriftyApp.swift`
- ✅ Added session tracking to app lifecycle in `MainAppView`
- ✅ Added premium feature tracking for camera scans

### 2. Session Tracking ✅
The app now automatically:
- Starts consumption tracking sessions when app becomes active
- Ends sessions when app goes to background
- Tracks premium feature usage (camera scans)
- Records play time for Apple's consumption metrics

## 🔧 Manual Configuration Steps Required

### 3. Firebase Functions Deployment

#### Prerequisites
1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

#### Deploy Functions
1. Navigate to functions directory:
   ```bash
   cd /Users/elianasilva/Desktop/thrift/functions
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Deploy to Firebase:
   ```bash
   firebase deploy --only functions
   ```

### 4. Firebase Environment Variables
Set these secrets in Firebase Console or CLI:

```bash
# Apple API Configuration
firebase functions:secrets:set APPLE_KEY_ID="YOUR_APPLE_KEY_ID"
firebase functions:secrets:set APPLE_ISSUER_ID="YOUR_APPLE_ISSUER_ID" 
firebase functions:secrets:set APPLE_PRIVATE_KEY="YOUR_BASE64_ENCODED_PRIVATE_KEY"

# RevenueCat API Key
firebase functions:secrets:set REVENUECAT_API_KEY="YOUR_REVENUECAT_API_KEY"

# Set environment variable for Apple environment
firebase functions:config:set apple.environment="SANDBOX"  # or "PRODUCTION"
```

### 5. Apple Developer Configuration

#### A. Generate App Store Connect API Key
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to Users and Access → Integrations → App Store Connect API
3. Click "Generate API Key"
4. Select "Admin" role
5. Download the `.p8` file
6. Note the Key ID and Issuer ID

#### B. Convert Private Key to Base64
```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
```
Use this base64 string for `APPLE_PRIVATE_KEY` secret.

#### C. Get Your App Store ID
1. Go to App Store Connect
2. Select your app
3. Go to App Information
4. Copy the Apple ID (numeric value)
5. Update `appleWebhook.js` line 17:
   ```javascript
   const appleAppId = "YOUR_ACTUAL_APP_STORE_ID";
   ```

### 6. App Store Connect Webhook Configuration

#### A. Get Your Firebase Function URL
After deploying functions, get the webhook URL:
```bash
firebase functions:list
```
Look for: `https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/appleConsumptionWebhook`

#### B. Configure Webhook in App Store Connect
1. Go to App Store Connect
2. Navigate to Apps → Your App → App Information
3. Scroll to "App Store Server Notifications"
4. Click "Add Endpoint"
5. Enter your Firebase function URL
6. Set notification types:
   - ✅ CONSUMPTION_REQUEST
   - ✅ REFUND (optional, for monitoring)
7. Test the endpoint

### 7. Apple Root Certificates
Download Apple's root certificates for verification:

1. Create certificates directory:
   ```bash
   mkdir -p /Users/elianasilva/Desktop/thrift/functions/certificates
   ```

2. Download Apple Root CA certificates:
   - [Apple Root CA - G3](https://www.apple.com/certificateauthority/AppleRootCA-G3.cer)
   - [Apple Root CA - G2](https://www.apple.com/certificateauthority/AppleRootCA-G2.cer)

3. Convert to PEM format and place in `functions/certificates/` directory

### 8. Update App Store ID
Replace placeholder in `functions/appleWebhook.js`:
```javascript
// Line 17
const appleAppId = "YOUR_ACTUAL_APP_STORE_ID"; // Replace with your App Store ID
```

### 9. RevenueCat Configuration
Ensure RevenueCat is properly configured:
1. Verify API key is correct
2. Ensure user IDs are properly mapped
3. Test purchase flow

## 🧪 Testing

### 1. Test in Sandbox Environment
1. Set `APPLE_ENVIRONMENT` to "SANDBOX"
2. Use TestFlight or Xcode simulator
3. Make test purchases
4. Check Firebase logs for consumption data

### 2. Verify Webhook Reception
1. Check Firebase Functions logs:
   ```bash
   firebase functions:log --only appleConsumptionWebhook
   ```

2. Look for successful webhook processing messages

### 3. Test Refund Flow
1. Request refund through iOS Settings → Apple ID → Media & Purchases
2. Verify consumption data is sent to Apple
3. Check Firebase logs for successful API calls

## 📊 Monitoring

### Firebase Console
- Monitor function executions
- Check error rates
- Review consumption data submissions

### App Store Connect
- Monitor refund requests
- Check webhook delivery status
- Review consumption data reception

## 🔒 Security Considerations

1. **API Keys**: Store all sensitive keys as Firebase secrets
2. **Webhook Verification**: Apple signatures are automatically verified
3. **Data Privacy**: Only necessary consumption metrics are shared
4. **Environment Separation**: Use separate keys for sandbox/production

## 🚀 Going Live

### Pre-Production Checklist
- [ ] All Firebase secrets configured
- [ ] Apple certificates downloaded and configured
- [ ] Webhook endpoint tested and verified
- [ ] App Store ID updated in code
- [ ] RevenueCat integration tested
- [ ] Consumption tracking verified in sandbox

### Production Deployment
1. Update environment to "PRODUCTION":
   ```bash
   firebase functions:config:set apple.environment="PRODUCTION"
   ```

2. Update webhook URL in App Store Connect to production endpoint

3. Deploy final version:
   ```bash
   firebase deploy --only functions
   ```

## 📞 Support

If you encounter issues:
1. Check Firebase Functions logs
2. Verify Apple webhook delivery in App Store Connect
3. Test with sandbox environment first
4. Ensure all API keys and certificates are correctly configured

## 📝 Additional Notes

- The system automatically tracks session time and premium feature usage
- Consumption data is only sent when Apple requests it (refund scenarios)
- All tracking respects user privacy and Apple's guidelines
- The integration is designed to work seamlessly with your existing RevenueCat setup

---

**Next Steps**: Follow the manual configuration steps above to complete your Apple consumption tracking integration.
