# 🔍 How to Verify App Store Connect Webhook Configuration

## 📋 **Step-by-Step Verification Guide**

---

## **Step 1: Access App Store Connect**

1. Go to: https://appstoreconnect.apple.com
2. Sign in with your Apple Developer account
3. Click on **"My Apps"**

---

## **Step 2: Navigate to Server Notifications**

### **Option A: If Your App is Already Published:**

1. Click on your **Thrifty** app
2. Click on **"App Information"** (in left sidebar)
3. Scroll down to **"App Store Server Notifications"** section

### **Option B: If App is Still in Development:**

1. Click on your **Thrifty** app
2. Look for **"General"** or **"App Information"** section
3. Look for **"Server Notifications"** or **"App Store Server API"**

**Alternate path if you can't find it:**
1. Users and Access → Keys → App Store Connect API
2. Or: App Information → General App Information → App Store Server Notifications

---

## **Step 3: Check Current Configuration**

You should see a section that looks like this:

```
┌─────────────────────────────────────────────────┐
│ App Store Server Notifications                  │
├─────────────────────────────────────────────────┤
│ Production Server URL:                          │
│ [                                              ] │
│                                                 │
│ Sandbox Server URL:                            │
│ [                                              ] │
│                                                 │
│ [ ] Version 2 Notifications                    │
│                                                 │
│ Notification Types:                            │
│ ☐ SUBSCRIBED                                   │
│ ☐ DID_RENEW                                    │
│ ☐ CONSUMPTION_REQUEST                          │
│ ☐ REFUND                                       │
│ ... (more types)                               │
└─────────────────────────────────────────────────┘
```

---

## **Step 4: Verify Your Settings**

### ✅ **What Should Be Configured:**

#### **1. Production Server URL:**
```
https://us-central1-thrift-882cb.cloudfunctions.net/appleConsumptionWebhook
```

#### **2. Sandbox Server URL:**
```
https://us-central1-thrift-882cb.cloudfunctions.net/appleConsumptionWebhook
```
*(Yes, same URL for both!)*

#### **3. Version:**
- ✅ **Version 2 Notifications** should be CHECKED
- ❌ NOT Version 1

#### **4. Notification Types:**
At minimum, you need:
- ✅ **CONSUMPTION_REQUEST** (this is critical!)
- ✅ **REFUND** (optional, but useful)
- ✅ **DID_CHANGE_RENEWAL_STATUS** (optional)
- ✅ **SUBSCRIBED** (optional)

---

## **Step 5: Test the Connection**

Some versions of App Store Connect have a **"Test Notification"** button:

1. Look for **"Send Test Notification"** button
2. Click it
3. Select notification type: **"CONSUMPTION_REQUEST"**
4. Apple will send a test notification to your webhook

**Check:**
- ✅ Your Firebase Function logs: https://console.firebase.google.com/project/thrift-882cb/functions/logs
- ✅ Should see incoming notification

---

## **Step 6: Verify Webhook is Accessible**

### **Test 1: Can Apple reach your webhook?**

Your webhook is public (good!), so test it:

```bash
curl https://us-central1-thrift-882cb.cloudfunctions.net/appleConsumptionWebhook
```

**Expected result:**
- Status: 400 or 405 (normal - it needs proper payload)
- ❌ NOT timeout or connection error

### **Test 2: Check Firebase Function Status**

1. Go to: https://console.firebase.google.com/project/thrift-882cb/functions
2. Find: `appleConsumptionWebhook`
3. Verify:
   - ✅ Status: **Healthy** (green)
   - ✅ Last deployed: Recent date
   - ✅ Region: `us-central1`

---

## 🚨 **Common Configuration Issues**

### **Issue 1: Webhook URL Not Set**

**Symptom:** Fields are empty
**Solution:** 
1. Enter your webhook URL in BOTH Production and Sandbox fields
2. Click **Save**
3. Wait 5 minutes for Apple's system to update

---

### **Issue 2: Wrong URL Format**

**❌ Wrong:**
```
http://us-central1-thrift-882cb.cloudfunctions.net/appleConsumptionWebhook
(missing 's' in https)

https://us-central1-thrift-882cb.cloudfunctions.net/appleConsumptionWebhook/
(trailing slash)

https://appleconsumptionwebhook-xhxqzuqe3q-uc.a.run.app
(old Cloud Run URL)
```

**✅ Correct:**
```
https://us-central1-thrift-882cb.cloudfunctions.net/appleConsumptionWebhook
```

---

### **Issue 3: Not Using Version 2**

**Symptom:** "Version 2 Notifications" is unchecked
**Solution:**
1. Check the **"Version 2 Notifications"** checkbox
2. Save
3. Your webhook only supports V2 (modern format)

---

### **Issue 4: CONSUMPTION_REQUEST Not Enabled**

**Symptom:** Other notification types are checked, but not CONSUMPTION_REQUEST
**Solution:**
1. Check **"CONSUMPTION_REQUEST"**
2. Save
3. This is THE critical notification type you need

---

### **Issue 5: App Not Connected to Webhook**

**Symptom:** Settings saved, but notifications not arriving
**Solution:**
1. Make sure you're configuring the correct app
2. Bundle ID should be: `com.thrifty.thrifty`
3. Verify in your app's "App Information" page

---

## 📊 **Visual Checklist**

Print this and check off each item:

```
☐ Logged into App Store Connect
☐ Found "App Store Server Notifications" section
☐ Production URL is set correctly
☐ Sandbox URL is set correctly
☐ Version 2 is enabled
☐ CONSUMPTION_REQUEST is checked
☐ Settings saved
☐ Webhook URL tested (responds, doesn't timeout)
☐ Firebase function is healthy
☐ Waited 5-10 minutes for changes to propagate
```

---

## 🧪 **How to Test Configuration**

### **Method 1: Use App Store Connect Test Notification**
(If available in your interface)

1. Click **"Send Test Notification"**
2. Select **CONSUMPTION_REQUEST**
3. Check Firebase logs immediately

### **Method 2: Make Real Sandbox Purchase**

1. Run app with Sandbox configuration
2. Make a purchase
3. Request refund
4. Wait 1-2 minutes
5. Check Firebase logs and Firestore

---

## 🔍 **Where to Look if Nothing Shows Up**

### **Check 1: Firebase Function Logs**
https://console.firebase.google.com/project/thrift-882cb/functions/logs

**Look for:**
```
✅ appleConsumptionWebhook invoked
📡 CONSUMPTION_REQUEST received
```

**If you see nothing:**
- Apple isn't calling your webhook
- Configuration issue in App Store Connect

### **Check 2: Firebase Function Metrics**
https://console.firebase.google.com/project/thrift-882cb/functions

**Look at:**
- Invocations count (should increase when Apple sends notification)
- Errors (if Apple is calling but failing)

### **Check 3: App Store Connect Activity**

Some App Store Connect versions show:
- Recent notifications sent
- Delivery status
- Error messages

---

## 🎯 **Quick Verification Script**

Run this to verify your webhook is reachable:

```bash
# Test webhook is accessible
curl -v https://us-central1-thrift-882cb.cloudfunctions.net/appleConsumptionWebhook

# Expected: 400 Bad Request (normal - needs payload)
# Bad: Timeout, connection refused, 404
```

---

## 📞 **Still Not Working?**

### **Checklist:**

1. **Wait Time:** Changes can take 5-10 minutes to propagate
2. **Environment:** Are you testing in Sandbox? Make sure Sandbox URL is set
3. **Bundle ID:** Verify your app's bundle ID matches
4. **Function:** Verify function is deployed and healthy
5. **Permissions:** Function allows unauthenticated calls (already configured ✅)

### **Advanced Debugging:**

1. **Check if webhook URL changed:**
   - Firebase sometimes changes Cloud Run URLs
   - Your current URL: `https://us-central1-thrift-882cb.cloudfunctions.net/appleConsumptionWebhook`
   - This should be stable for Cloud Functions v2

2. **Check function permissions:**
   ```bash
   cd /Users/elianasilva/Desktop/thrift/functions
   firebase functions:config:get
   ```

3. **Verify secrets are set:**
   - APPLE_KEY_ID
   - APPLE_ISSUER_ID
   - APPLE_PRIVATE_KEY
   - REVENUECAT_API_KEY

---

## ✅ **Success Indicators**

You'll know it's working when:

1. ✅ You request a refund in your app
2. ✅ Within 1-2 minutes, you see in Firebase logs:
   ```
   📡 CONSUMPTION_REQUEST received for transaction: 15
   ✅ Consumption request logged to Firestore
   ```
3. ✅ A new document appears in `consumption_requests` collection
4. ✅ Document has real Apple data (not test data)

---

## 🆘 **Can't Find Server Notifications Section?**

### **Alternative Navigation Paths:**

**Path 1:**
1. App Store Connect → My Apps
2. Select your app
3. **Features** tab (top menu)
4. Look for **In-App Purchase** or **Subscriptions**
5. Server Notifications link may be there

**Path 2:**
1. App Store Connect → My Apps
2. Select your app
3. **App Information** (left sidebar)
4. Scroll to bottom
5. Look for **App Store Server Notifications**

**Path 3:**
1. App Store Connect → My Apps
2. Select your app
3. Look under **General** → **App Information**
4. **Version 2 Server Notifications**

**Path 4:**
If you can't find it at all, your app might need to:
- Have at least one in-app purchase created
- Be submitted for review at least once
- Have the "App Store Server Notifications" feature enabled

---

## 📝 **Screenshot Locations**

When you find the section, take screenshots of:

1. ✅ Production Server URL field (filled)
2. ✅ Sandbox Server URL field (filled)
3. ✅ Version 2 checkbox (checked)
4. ✅ Notification types (CONSUMPTION_REQUEST checked)
5. ✅ Any status indicators or test buttons

This will help verify configuration if issues arise!

---

## 🎯 **Bottom Line:**

**Your webhook URL:**
```
https://us-central1-thrift-882cb.cloudfunctions.net/appleConsumptionWebhook
```

**Must be entered in BOTH fields:**
- Production Server URL
- Sandbox Server URL

**In App Store Connect:**
- Your App → App Information → App Store Server Notifications
- Enable Version 2
- Check CONSUMPTION_REQUEST
- Save and wait 5-10 minutes

**Then test with a real Sandbox refund request!**

