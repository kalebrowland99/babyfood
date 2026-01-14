# 🔥 Firebase Console Setup - Step by Step

## ⚠️ IMPORTANT: Complete These Steps Before Testing

Your app is ready to use authentication, but you need to enable the authentication methods in Firebase Console first.

---

## 📋 Step-by-Step Instructions

### 1. Open Firebase Console
1. Go to: https://console.firebase.google.com/
2. Sign in with your Google account
3. Click on your project: **cal-app-f3017**

### 2. Navigate to Authentication
1. In the left sidebar, click **"Build"**
2. Click **"Authentication"**
3. Click the **"Get started"** button (if you see it)
4. Click on the **"Sign-in method"** tab at the top

---

## 🔐 Enable Authentication Methods

### Method 1: Email/Password ✉️

1. In the "Sign-in providers" list, find **"Email/Password"**
2. Click on it
3. Toggle the **"Enable"** switch to ON
4. Click **"Save"**

✅ Done! Email/Password authentication is now active.

---

### Method 2: Google Sign-In 🔵

1. In the "Sign-in providers" list, find **"Google"**
2. Click on it
3. Toggle the **"Enable"** switch to ON
4. In the "Project support email" dropdown, select your email address
5. Click **"Save"**

✅ Done! Google Sign-In is now active.

**Note:** Your OAuth credentials are already configured:
- Client ID: `477330728361-mniq4fdcdfdt13n7tghcs867kfmld5pt.apps.googleusercontent.com`
- This is already in your app's configuration

---

### Method 3: Apple Sign-In 🍎

1. In the "Sign-in providers" list, find **"Apple"**
2. Click on it
3. Toggle the **"Enable"** switch to ON
4. Click **"Save"**

✅ Done! Apple Sign-In is now active.

**Note:** Apple Sign-In is already configured in your app:
- Capability enabled in entitlements
- Bundle ID: `invoice.app`

---

## ✅ Verification

After enabling all three methods, you should see:

```
Sign-in providers
├── Email/Password     [Enabled]
├── Google            [Enabled]
└── Apple             [Enabled]
```

---

## 🧪 Test Your Setup

### Test 1: Email/Password
1. Run your app in Xcode
2. You should see the login screen
3. Tap **"Sign Up"** at the bottom
4. Enter:
   - Full Name: "Test User"
   - Email: "test@example.com"
   - Password: "password123"
5. Tap **"Sign Up"** button
6. ✅ You should be logged in and see the main app

### Test 2: Google Sign-In
1. Logout from the Profile tab
2. On the login screen, tap **"Continue with Google"**
3. Select your Google account
4. Grant permissions
5. ✅ You should be logged in

### Test 3: Apple Sign-In
1. Logout from the Profile tab
2. On the login screen, tap **"Sign In with Apple"**
3. Use Face ID/Touch ID or enter your Apple ID password
4. ✅ You should be logged in

### Test 4: Logout
1. Go to the **Profile** tab
2. Scroll down to **"Account Actions"**
3. Tap **"Logout"**
4. Confirm in the alert
5. ✅ You should return to the login screen

---

## 🎯 What You'll See in Firebase Console After Testing

### Users Tab
After users sign up/sign in, you'll see them in:
**Authentication** → **Users** tab

Each user will show:
- User ID (UID)
- Email address
- Sign-in provider (Email, Google, or Apple)
- Created date
- Last sign-in date

---

## 🔧 Optional: Customize Email Templates

If you want to customize the password reset email:

1. In Firebase Console, go to **Authentication**
2. Click on **"Templates"** tab
3. Click on **"Password reset"**
4. Customize the email template
5. Click **"Save"**

---

## 🆘 Troubleshooting

### "Authentication not enabled" error
- Make sure you enabled the authentication methods in Firebase Console
- Wait a few seconds after enabling for changes to propagate

### Google Sign-In not working
- Verify you selected a support email in the Google provider settings
- Check that your OAuth client ID matches in Google Cloud Console

### Apple Sign-In not working
- Make sure you're testing on a real device or simulator with an Apple ID signed in
- Verify the capability is enabled in Xcode

### Users not appearing in Firebase Console
- Check you're looking at the correct project (cal-app-f3017)
- Refresh the page
- Check the "Users" tab, not "Sign-in method"

---

## 📊 Monitoring Authentication

### View Active Users
**Authentication** → **Users** tab
- See all registered users
- View their sign-in methods
- Delete users if needed

### View Sign-In Activity
**Authentication** → **Usage** tab
- See daily active users
- Track authentication events
- Monitor errors

---

## 🎉 You're All Set!

Once you've completed these steps:
1. ✅ All three authentication methods are enabled
2. ✅ Users can sign up and sign in
3. ✅ User data is stored in Firebase
4. ✅ Your app handles authentication automatically

**Time to enable:** ~2 minutes  
**Time to test:** ~5 minutes

---

## 📝 Quick Checklist

- [ ] Opened Firebase Console
- [ ] Navigated to Authentication → Sign-in method
- [ ] Enabled Email/Password
- [ ] Enabled Google (with support email)
- [ ] Enabled Apple
- [ ] Tested sign up with email
- [ ] Tested Google Sign-In
- [ ] Tested Apple Sign-In
- [ ] Tested logout
- [ ] Verified users appear in Firebase Console

---

**That's it!** Your authentication system is fully functional. 🚀

For detailed technical documentation, see: `FIREBASE_AUTH_SETUP.md`
