# 🎯 Meta Conversions API Setup Guide

## ✅ What's Implemented

Your app now has **dual tracking** for Meta Ads:
1. **SKAdNetwork** - Apple's attribution (already working ✅)
2. **Meta Conversions API** - Server-to-server tracking (needs credentials)

---

## 🔑 Step 1: Get Your Meta Credentials

### A. Get Your Pixel ID

1. Go to **Meta Events Manager**: https://business.facebook.com/events_manager2
2. Select your **Pixel** (or create one if you don't have it)
3. Copy your **Pixel ID** (it's a long number like `123456789012345`)

### B. Generate Access Token

1. Go to **Meta Business Settings**: https://business.facebook.com/settings
2. Navigate to: **System Users** → Create or select a system user
3. Click **Generate New Token**
4. Select your **App** and **Ad Account**
5. Required permissions:
   - ✅ `ads_management`
   - ✅ `business_management`
6. Copy the **Access Token** (starts with `EAA...`)

**⚠️ IMPORTANT:** Keep this token secure! It has access to your ad account.

---

## 🔧 Step 2: Set Firebase Environment Variables

### Option A: Using Firebase CLI (Recommended)

```bash
cd /Users/elianasilva/Desktop/thrift/functions

# Set Meta Pixel ID
firebase functions:config:set meta.pixel_id="YOUR_PIXEL_ID_HERE"

# Set Meta Access Token
firebase functions:config:set meta.access_token="YOUR_ACCESS_TOKEN_HERE"
```

### Option B: Using Google Cloud Console

1. Go to: https://console.cloud.google.com
2. Select project: **thrift-882cb**
3. Navigate to: **Cloud Functions** → Select function → **Edit**
4. Go to **Runtime, build, connections and security settings**
5. Under **Runtime environment variables**, add:
   - `META_PIXEL_ID` = `your_pixel_id`
   - `META_ACCESS_TOKEN` = `your_access_token`

---

## 🚀 Step 3: Deploy Firebase Functions

```bash
cd /Users/elianasilva/Desktop/thrift/functions

# Deploy the new function
firebase deploy --only functions:sendMetaPurchaseEvent
```

---

## 🧪 Step 4: Test the Implementation

### Test in Development:

1. **Make a test purchase** in your app
2. **Check Xcode console** for:
   ```
   📘 Sending Meta purchase event for yearly - $149
   ✅ Meta Conversions API: Purchase event sent successfully
   📊 Meta response: {...}
   ```
3. **Check Firebase Console** → Functions → Logs for:
   ```
   ✅ Meta purchase event sent successfully for yearly
   ```

### Verify in Meta Events Manager:

1. Go to: https://business.facebook.com/events_manager2
2. Select your **Pixel**
3. Click **Test Events**
4. Make a purchase → You should see the event appear within seconds
5. Check **Overview** tab for Purchase events (may take 10-15 minutes)

---

## 📊 What Gets Sent to Meta

For each purchase, the following data is sent:

```javascript
{
  event_name: "Purchase",
  event_time: 1234567890,           // Unix timestamp
  action_source: "app",             // iOS app
  user_data: {
    em: ["hashed_email"],           // SHA256 hashed email
  },
  custom_data: {
    value: 149.00,                  // Purchase amount
    currency: "USD",
    content_name: "yearly",         // Plan type
  },
  event_id: "transaction_id_123",  // For deduplication
}
```

---

## 🔍 Monitoring & Debugging

### Check Firebase Logs:
```bash
firebase functions:log --only sendMetaPurchaseEvent
```

### Check Firestore Collection:
- Collection: `meta_events`
- Contains all sent events with success/failure status
- Go to Firebase Console → Firestore Database → `meta_events`

### Common Issues:

**1. "Meta credentials not configured"**
- Solution: Set `META_PIXEL_ID` and `META_ACCESS_TOKEN` environment variables

**2. "Invalid access token"**
- Solution: Regenerate access token in Meta Business Settings
- Ensure token has `ads_management` permission

**3. "Pixel not found"**
- Solution: Verify Pixel ID is correct (no spaces, just numbers)

**4. Events not showing in Meta Events Manager**
- Wait 10-15 minutes (Meta has a delay)
- Check Test Events tab for real-time data
- Verify user email is being captured

---

## 🎯 Event Deduplication

Your implementation uses **transaction IDs** to prevent duplicate events:
- Same `transactionId` sent to both SKAdNetwork and Conversions API
- Meta automatically deduplicates events with same `event_id`
- Prevents double-counting conversions

---

## 📈 Expected Results

After setup, you should see in Meta Ads Manager:
- **Purchase events** from iOS users
- **Revenue tracking** with actual dollar amounts
- **Better attribution** for iOS 14+ users (bypasses ATT)
- **Improved ROAS** data for campaign optimization

---

## 🔒 Security Notes

1. **Access Token Security:**
   - Never commit access token to git
   - Use environment variables only
   - Rotate tokens every 60-90 days

2. **Email Hashing:**
   - Emails are SHA256 hashed before sending
   - Meta uses hashed emails for matching
   - Compliant with privacy regulations

3. **Firestore Logging:**
   - Full emails are NOT stored in Firestore
   - Only stores masked email indicator (`***`)
   - Transaction IDs logged for debugging

---

## 🆘 Need Help?

### Firebase Functions Documentation:
https://firebase.google.com/docs/functions

### Meta Conversions API Documentation:
https://developers.facebook.com/docs/marketing-api/conversions-api

### Test Your Setup:
1. Enable Test Events in Meta Events Manager
2. Make a test purchase
3. Verify event appears in Test Events tab

---

## ✅ Setup Checklist

- [ ] Get Meta Pixel ID from Events Manager
- [ ] Generate Access Token with correct permissions
- [ ] Set Firebase environment variables
- [ ] Deploy Firebase function: `sendMetaPurchaseEvent`
- [ ] Test purchase and verify in Meta Events Manager
- [ ] Check Firestore `meta_events` collection
- [ ] Monitor Firebase function logs
- [ ] Verify events in Meta Ads Manager (wait 15 mins)

---

🎉 **Once complete, your Meta Ads will receive accurate, server-side purchase events that bypass iOS 14+ ATT limitations!**

