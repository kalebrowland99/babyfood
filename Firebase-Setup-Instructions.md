# Firebase Authentication Setup Instructions

## Prerequisites
- Apple Developer Account
- Firebase Project
- Xcode with your app configured

## Step 1: Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing one
3. Add iOS app to your Firebase project
   - Bundle ID: `com.TrvzrWViGDUN.LyricsGenerator` (or your actual bundle ID)
   - App nickname: `Thrifty`
   - Download `GoogleService-Info.plist`

## Step 2: Add Firebase Dependencies

Add to your Xcode project via Swift Package Manager:
```
https://github.com/firebase/firebase-ios-sdk
```

Select these products:
- FirebaseAuth
- FirebaseCore
- GoogleSignIn

## Step 3: Configure Firebase

1. Add `GoogleService-Info.plist` to your Xcode project
2. In `ThriftyApp.swift`, add Firebase configuration:

```swift
import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct ThriftyApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    
    init() {
        FirebaseApp.configure()
        
        // Configure Google Sign In
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            fatalError("GoogleService-Info.plist not found or CLIENT_ID missing")
        }
        
        GoogleSignIn.GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoggedIn {
                    MainAppView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isLoggedIn)
            .onOpenURL { url in
                GoogleSignIn.GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
```

## Step 4: Update URL Schemes

1. In Xcode, go to your target's Info tab
2. Expand "URL Types" section
3. Add a new URL scheme with your reversed CLIENT_ID from GoogleService-Info.plist
   - Example: `com.googleusercontent.apps.123456789-abcdefg`

## Step 5: Enable Authentication Methods in Firebase

1. Go to Firebase Console → Authentication → Sign-in method
2. Enable:
   - Google (configure OAuth consent screen)
   - Email/Password
   - Apple (add your Apple Developer Team ID and Key ID)

## Step 6: Update AuthenticationManager

Replace the placeholder methods in `AuthenticationManager` with real Firebase implementations:

```swift
import FirebaseAuth
import GoogleSignIn

// In AuthenticationManager class:

// Real Google Sign In implementation
func signInWithGoogle() {
    isLoading = true
    errorMessage = nil
    
    guard let presentingViewController = UIApplication.shared.windows.first?.rootViewController else {
        errorMessage = "Unable to find presenting view controller"
        isLoading = false
        return
    }
    
    GoogleSignIn.GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
        DispatchQueue.main.async {
            if let error = error {
                self?.errorMessage = "Google Sign In failed: \(error.localizedDescription)"
                self?.isLoading = false
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                self?.errorMessage = "Failed to get Google ID token"
                self?.isLoading = false
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    self?.errorMessage = "Firebase authentication failed: \(error.localizedDescription)"
                    self?.isLoading = false
                    return
                }
                
                guard let firebaseUser = authResult?.user else {
                    self?.errorMessage = "Failed to get Firebase user"
                    self?.isLoading = false
                    return
                }
                
                let userData = UserData(
                    id: firebaseUser.uid,
                    email: firebaseUser.email,
                    name: firebaseUser.displayName,
                    profileImageURL: firebaseUser.photoURL?.absoluteString,
                    authProvider: .google
                )
                
                self?.completeSignIn(with: userData)
            }
        }
    }
}

// Real Email Sign In implementation
func signInWithEmail(email: String, password: String) {
    isLoading = true
    errorMessage = nil
    
    Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
        DispatchQueue.main.async {
            if let error = error {
                self?.errorMessage = "Email sign in failed: \(error.localizedDescription)"
                self?.isLoading = false
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                self?.errorMessage = "Failed to get Firebase user"
                self?.isLoading = false
                return
            }
            
            let userData = UserData(
                id: firebaseUser.uid,
                email: firebaseUser.email,
                name: firebaseUser.displayName,
                profileImageURL: firebaseUser.photoURL?.absoluteString,
                authProvider: .email
            )
            
            self?.completeSignIn(with: userData)
        }
    }
}

// Email Sign Up implementation
func signUpWithEmail(email: String, password: String) {
    isLoading = true
    errorMessage = nil
    
    Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
        DispatchQueue.main.async {
            if let error = error {
                self?.errorMessage = "Email sign up failed: \(error.localizedDescription)"
                self?.isLoading = false
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                self?.errorMessage = "Failed to get Firebase user"
                self?.isLoading = false
                return
            }
            
            let userData = UserData(
                id: firebaseUser.uid,
                email: firebaseUser.email,
                name: firebaseUser.displayName,
                profileImageURL: firebaseUser.photoURL?.absoluteString,
                authProvider: .email
            )
            
            self?.completeSignIn(with: userData)
        }
    }
}

// Update logout to sign out from Firebase
func logOut() {
    do {
        try Auth.auth().signOut()
        GoogleSignIn.GIDSignIn.sharedInstance.signOut()
        
        currentUser = nil
        isLoggedIn = false
        isLoading = false
        errorMessage = nil
        saveAuthenticationState()
        print("🚪 User logged out - redirecting to sign in")
    } catch {
        errorMessage = "Failed to log out: \(error.localizedDescription)"
    }
}
```

## Step 7: Testing

1. Test Apple Sign In (should work immediately)
2. Test Google Sign In (requires Firebase setup)
3. Test Email Sign In/Sign Up (requires Firebase setup)

## Notes

- Apple Sign In is fully implemented and working
- Google and Email authentication are currently simulated but will work once Firebase is configured
- Make sure to add proper error handling for network failures
- Consider implementing password reset functionality for email authentication
- Add user profile management features as needed

## Security Considerations

- Never store passwords locally
- Use Firebase Security Rules to protect user data
- Implement proper session management
- Consider adding two-factor authentication for enhanced security 