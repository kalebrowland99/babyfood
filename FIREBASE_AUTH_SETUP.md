# Firebase Authentication Setup Guide

This guide explains how Firebase Authentication has been integrated into your Invoice app with Google Sign-In, Apple Sign-In, and Email/Password authentication.

## ✅ What's Been Set Up

### 1. **Authentication Manager** (`AuthenticationManager.swift`)
- Centralized authentication state management
- Handles user sign-in, sign-up, and sign-out
- Supports three authentication methods:
  - **Email/Password** - Traditional email and password authentication
  - **Google Sign-In** - OAuth authentication via Google
  - **Apple Sign-In** - Native Apple authentication

### 2. **Login UI** (`LoginView.swift`)
- Beautiful, modern login interface
- Sign In with Apple button (native iOS component)
- Google Sign-In button
- Email/Password form with validation
- Toggle between Sign In and Sign Up modes
- Forgot Password functionality
- Error handling with user-friendly alerts

### 3. **App Integration** (`InvoiceApp.swift`)
- Firebase initialization on app launch
- Automatic routing between LoginView and ContentView based on auth state
- AuthenticationManager available as environment object throughout the app

### 4. **Profile Integration** (`ContentView.swift`)
- User profile display with avatar and email
- Logout functionality with confirmation
- Delete account option with confirmation
- User info displayed in ProfileView

## 🔧 Configuration Already in Place

### Firebase Configuration
- ✅ `GoogleService-Info.plist` is configured
- ✅ Firebase SDK packages are installed
- ✅ Bundle ID: `invoice.app`
- ⚠️ Project ID: **Update to `cal-app-f3017`** (see SETUP_NEW_FIREBASE_PROJECT.md)

### Google Sign-In
- ✅ GoogleSignIn Swift Package installed (v7.0.0+)
- ✅ URL Scheme configured: `com.googleusercontent.apps.477330728361-mniq4fdcdfdt13n7tghcs867kfmld5pt`
- ✅ Client ID configured in Info.plist

### Apple Sign-In
- ✅ Sign In with Apple capability enabled in entitlements
- ✅ Keychain access groups configured

## 🚀 Next Steps - Firebase Console Setup

### 1. Enable Authentication Methods in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **cal-app-f3017**
3. Navigate to **Authentication** → **Sign-in method**

#### Enable Email/Password:
1. Click on **Email/Password**
2. Toggle **Enable**
3. Click **Save**

#### Enable Google Sign-In:
1. Click on **Google**
2. Toggle **Enable**
3. Set project support email
4. Click **Save**

#### Enable Apple Sign-In:
1. Click on **Apple**
2. Toggle **Enable**
3. Click **Save**

### 2. Apple Developer Console Setup (for Apple Sign-In)

1. Go to [Apple Developer Console](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select your app identifier: `invoice.app`
4. Ensure **Sign In with Apple** capability is enabled
5. Configure your Service ID if needed for web authentication

### 3. Google Cloud Console Setup (for Google Sign-In)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Navigate to **APIs & Services** → **Credentials**
4. Verify your OAuth 2.0 Client IDs are configured:
   - iOS Client ID: `477330728361-mniq4fdcdfdt13n7tghcs867kfmld5pt.apps.googleusercontent.com`
   - Bundle ID: `invoice.app`

## 📱 How It Works

### User Flow:

1. **App Launch**
   - If user is logged in → Show ContentView (main app)
   - If user is not logged in → Show LoginView

2. **Login Options**
   - **Sign In with Apple**: Native iOS authentication
   - **Continue with Google**: OAuth flow via Google
   - **Email/Password**: Manual sign up or sign in

3. **After Login**
   - User is automatically redirected to ContentView
   - User info is available via `authManager.user`
   - Profile displays user name and email

4. **Logout**
   - User taps Logout in Profile tab
   - Confirmation alert appears
   - User is signed out and returned to LoginView

## 🔐 Security Features

- **Secure Authentication**: All auth handled by Firebase
- **Token Management**: Automatic token refresh
- **Keychain Storage**: Credentials stored securely in iOS Keychain
- **State Persistence**: User stays logged in between app launches
- **Nonce Validation**: Apple Sign-In uses cryptographic nonce for security

## 🎨 UI Features

- Modern, clean design matching your app's aesthetic
- Smooth animations and transitions
- Loading states during authentication
- Error handling with user-friendly messages
- Form validation (email format, password requirements)
- Forgot password flow

## 📝 Usage in Code

### Access Current User
```swift
@EnvironmentObject var authManager: AuthenticationManager

// Get current user
if let user = authManager.user {
    print("User email: \(user.email ?? "No email")")
    print("User name: \(user.displayName ?? "No name")")
    print("User ID: \(user.uid)")
}

// Check if authenticated
if authManager.isAuthenticated {
    // User is logged in
}
```

### Sign Out
```swift
do {
    try authManager.signOut()
} catch {
    print("Error: \(error.localizedDescription)")
}
```

### Delete Account
```swift
Task {
    do {
        try await authManager.user?.delete()
        try authManager.signOut()
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}
```

## 🧪 Testing

### Test Email/Password:
1. Run the app
2. Tap "Sign Up"
3. Enter name, email, and password
4. Tap "Sign Up" button
5. You should be logged in and see the main app

### Test Google Sign-In:
1. Run the app
2. Tap "Continue with Google"
3. Select a Google account
4. Grant permissions
5. You should be logged in

### Test Apple Sign-In:
1. Run the app
2. Tap "Sign In with Apple"
3. Use Face ID/Touch ID or password
4. You should be logged in

### Test Logout:
1. Go to Profile tab
2. Scroll down to "Account Actions"
3. Tap "Logout"
4. Confirm in alert
5. You should return to login screen

## 📦 Dependencies

The following packages are already installed:
- `firebase-ios-sdk` (v10.29.0) - Firebase core and auth
- `GoogleSignIn-iOS` (v7.0.0+) - Google Sign-In

## 🔍 Files Modified/Created

### New Files:
- `Invoice/AuthenticationManager.swift` - Authentication logic
- `Invoice/LoginView.swift` - Login UI

### Modified Files:
- `Invoice/InvoiceApp.swift` - Firebase initialization and auth routing
- `Invoice/ContentView.swift` - Profile integration with auth

### Existing Configuration:
- `Invoice/GoogleService-Info.plist` - Firebase config
- `Invoice/Invoice.entitlements` - Apple Sign-In capability
- `Invoice-Info.plist` - URL schemes and client IDs

## 🎯 Next Steps for Production

1. **Enable authentication methods in Firebase Console** (see above)
2. **Test all authentication flows** thoroughly
3. **Set up password reset email templates** in Firebase Console
4. **Configure email verification** if needed
5. **Add user profile management** (update name, email, photo)
6. **Implement data sync** with Firestore for user-specific data
7. **Add analytics** to track authentication events
8. **Set up proper error handling** for network issues

## 💡 Tips

- Users can sign in with multiple methods using the same email
- Firebase automatically links accounts with the same email
- Apple Sign-In allows users to hide their email (relay email)
- Google Sign-In requires valid OAuth credentials
- Test on real devices for best results with biometric authentication

## 🆘 Troubleshooting

### Google Sign-In not working:
- Verify OAuth Client ID in Google Cloud Console
- Check bundle ID matches in all configs
- Ensure URL scheme is correctly configured

### Apple Sign-In not working:
- Verify capability is enabled in Xcode
- Check entitlements file
- Ensure you're testing on a real device or simulator with Apple ID

### Firebase errors:
- Check `GoogleService-Info.plist` is in the project
- Verify Firebase.configure() is called before any auth operations
- Check Firebase Console for enabled authentication methods

---

**Setup Complete! 🎉**

Your app now has a complete authentication system with Google, Apple, and Email/Password sign-in options.
