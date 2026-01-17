# TestFlight Upload Guide - Complete Steps

## Your App Details
- **Bundle ID:** `calai.app`
- **App Name:** Cal AI / Thrifty (update as needed)

---

## STEP 1: Apple Developer Account Setup

### 1.1 Ensure You Have:
- [ ] Apple Developer Program membership ($99/year)
- [ ] Go to: https://developer.apple.com/account
- [ ] Login with your Apple ID
- [ ] If not enrolled, enroll at: https://developer.apple.com/programs/enroll/

### 1.2 Add Your Client as a Tester (Optional)
You can add them later in TestFlight

---

## STEP 2: Create App in App Store Connect

### 2.1 Go to App Store Connect
1. Visit: https://appstoreconnect.apple.com
2. Click **"My Apps"**
3. Click the **"+"** button → **"New App"**

### 2.2 Fill in App Information
- **Platform:** iOS
- **Name:** Cal AI (or your client's preferred name)
- **Primary Language:** English
- **Bundle ID:** Select `calai.app` from dropdown
- **SKU:** `calai-app-001` (can be anything unique)
- **User Access:** Full Access

### 2.3 Click "Create"

---

## STEP 3: Prepare Xcode for Archive

### 3.1 Open Your Project in Xcode
```bash
open /Users/kaleb/Desktop/invoice/Invoice.xcodeproj
```

### 3.2 Select "Any iOS Device (arm64)" as Build Target
- At the top of Xcode, click on the device selector
- Choose **"Any iOS Device (arm64)"** (NOT a simulator!)

### 3.3 Update Version & Build Number
1. Click on your project in the navigator (top blue icon)
2. Select the **"Invoice"** target
3. Go to **"General"** tab
4. Under **"Identity"** section:
   - **Version:** `1.0.0` (or your version)
   - **Build:** `1` (increment for each upload)

### 3.4 Set Signing & Capabilities
1. Still in **"General"** tab, scroll to **"Signing & Capabilities"**
2. **Uncheck** "Automatically manage signing"
3. Then **Re-check** "Automatically manage signing"
4. Select your **Team** (your Apple Developer account)
5. Xcode will automatically create:
   - Provisioning Profile
   - App ID
   - Certificates

### 3.5 Verify No Errors
- Look for red error icons in the "Signing & Capabilities" section
- Common fix: Click "Download Manual Profiles" if you see signing errors

---

## STEP 4: Configure Release Settings

### 4.1 Edit Scheme
1. Click **"Product"** menu → **"Scheme"** → **"Edit Scheme..."**
2. Select **"Run"** on the left
3. Change **"Build Configuration"** to **"Release"**
4. Click **"Close"**

### 4.2 Set Deployment Target
1. In project settings → **"General"** tab
2. Set **"Minimum Deployments"** to `iOS 16.0` (or your minimum)

---

## STEP 5: Archive the App

### 5.1 Clean Build Folder
1. Click **"Product"** menu
2. Hold **Option key** and click **"Clean Build Folder"** (not just "Clean")
3. Wait for it to complete

### 5.2 Create Archive
1. Click **"Product"** menu → **"Archive"**
2. Wait for the build to complete (may take 2-10 minutes)
3. **Organizer window** will open automatically when done

### 5.3 If Archive is Disabled:
- Make sure you selected **"Any iOS Device (arm64)"** not a simulator
- Go back to Step 3.2

---

## STEP 6: Upload to App Store Connect

### 6.1 In Organizer Window
1. You should see your archive listed
2. Click **"Distribute App"** button

### 6.2 Select Distribution Method
1. Choose **"App Store Connect"**
2. Click **"Next"**

### 6.3 Select Upload
1. Choose **"Upload"**
2. Click **"Next"**

### 6.4 Distribution Options
1. **App Thinning:** All compatible device variants
2. **Rebuild from Bitcode:** Yes (if available)
3. **Include symbols:** Yes (recommended for crash reports)
4. Click **"Next"**

### 6.5 Re-sign Automatically
1. Choose **"Automatically manage signing"**
2. Click **"Next"**

### 6.6 Review and Upload
1. Review the summary
2. Click **"Upload"**
3. Wait for upload to complete (may take 5-15 minutes)
4. You'll see "Upload Successful" message

---

## STEP 7: Process Build in App Store Connect

### 7.1 Wait for Processing
1. Go to https://appstoreconnect.apple.com
2. Click **"My Apps"** → Your app
3. Click **"TestFlight"** tab at the top
4. You'll see your build under **"iOS"** section
5. Status will be **"Processing"** (⚠️ this takes 5-30 minutes)

### 7.2 Export Compliance
Once processing is done:
1. You'll see a yellow warning: **"Missing Compliance"**
2. Click on your build
3. Click **"Manage"** next to Export Compliance
4. Answer the questions:
   - **Does your app use encryption?** → Usually "No" unless you added custom encryption
   - If it only uses standard iOS HTTPS → Answer "No"
5. Click **"Start Internal Testing"**

---

## STEP 8: Add Your Client as a Tester

### 8.1 Create Test Group
1. In **TestFlight** tab
2. Click **"App Store Connect Users"** under **"Internal Group"** OR
3. Click **"External Testers"** in left sidebar → **"Create Group"**
4. Name it: "Client Testing" or similar

### 8.2 Add Tester
1. Click **"+"** to add testers
2. Enter your client's:
   - **First Name**
   - **Last Name**
   - **Email** (they'll receive invite here)
3. Click **"Add"**

### 8.3 Enable Build for Testing
1. Select your test group
2. Click **"Builds"** section
3. Click **"+"** to add your build
4. Select your build and click **"Next"**
5. Add **"What to Test"** notes (optional):
   ```
   Version 1.0.0 - Initial test build
   
   Please test:
   - Russian language display
   - Progress screen layout
   - All onboarding flows
   ```
6. Click **"Submit for Review"** (for External Testing) or just enable (for Internal)

---

## STEP 9: Client Installation

### 9.1 Client Receives Email
Your client will get an email: **"You're invited to test [App Name]"**

### 9.2 Client Setup
1. Install **TestFlight** app from App Store (if not installed)
2. Click the link in the email OR enter the code
3. Accept the invitation
4. Tap **"Install"** to download your app
5. App appears on their home screen

### 9.3 Client Can Provide Feedback
- Open TestFlight app
- Select your app
- Tap **"Send Beta Feedback"**
- Can include screenshots

---

## TROUBLESHOOTING

### "No signing certificate found"
**Fix:**
1. Xcode → **Preferences** → **Accounts**
2. Select your Apple ID
3. Click **"Download Manual Profiles"**
4. Or: Click **"Manage Certificates"** → **"+"** → **"Apple Distribution"**

### "Archive option is grayed out"
**Fix:**
- Change build target from simulator to **"Any iOS Device (arm64)"**

### "Missing Compliance" never goes away
**Fix:**
1. App Store Connect → TestFlight → Your Build
2. Click yellow warning
3. Answer encryption questions
4. Save

### "Build is processing for too long" (>1 hour)
**Fix:**
- Usually resolves itself
- Check https://developer.apple.com/system-status/
- Try uploading a new build with incremented build number

### Client can't install (device incompatible)
**Fix:**
- Check your **Minimum Deployment Target** in Xcode
- Make sure client's iOS version ≥ your minimum
- Update in Xcode → Project Settings → General → Deployment Info

---

## QUICK CHECKLIST

- [ ] Apple Developer Account active ($99/year)
- [ ] App created in App Store Connect
- [ ] Bundle ID matches: `calai.app`
- [ ] Build target set to "Any iOS Device (arm64)"
- [ ] Version and Build numbers set
- [ ] Signing configured (Automatically manage signing)
- [ ] Clean build folder completed
- [ ] Archive created successfully
- [ ] Uploaded to App Store Connect
- [ ] Build processed (no longer "Processing")
- [ ] Export compliance completed
- [ ] Client added as tester
- [ ] Build enabled for test group
- [ ] Client received invitation email
- [ ] Client installed TestFlight
- [ ] Client installed your app
- [ ] App works correctly on client's device

---

## SUBSEQUENT UPLOADS (Updates)

When you need to upload a new version:

1. **Increment Build Number** in Xcode
   - General tab → Build: `2`, `3`, `4`, etc.
   
2. **Clean & Archive**
   - Product → Clean Build Folder
   - Product → Archive
   
3. **Upload**
   - Distribute App → App Store Connect → Upload
   
4. **Enable for Testing**
   - TestFlight → Add build to test group
   
5. **Client Updates Automatically**
   - TestFlight will notify them
   - Or they can manually update in TestFlight app

---

## TIPS

- **Internal Testing:** Up to 100 testers, no review needed, instant
- **External Testing:** Up to 10,000 testers, requires Apple review (~24-48hrs)
- **Build expiry:** TestFlight builds expire after 90 days
- **Feedback:** Clients can send screenshots and feedback through TestFlight
- **Crashes:** You can see crash reports in Xcode → Window → Organizer → Crashes

---

## NEED HELP?

Common issues are usually:
1. **Signing problems** → Re-enable "Automatically manage signing"
2. **Archive disabled** → Select "Any iOS Device" not simulator
3. **Processing stuck** → Wait 30 min, check Apple status page
4. **Missing compliance** → Answer encryption questions in App Store Connect

---

**Good luck with your TestFlight distribution!** 🚀
