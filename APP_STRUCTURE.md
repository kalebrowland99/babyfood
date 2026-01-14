# Cal AI App Structure Documentation
**Last Updated:** January 14, 2026
**Working File:** `ContentView.swift.working_backup_20260114_140241`

## ⚠️ IMPORTANT - FILE ORGANIZATION

This app currently has **ONE MAIN FILE**: `ContentView.swift` (15,999 lines)
- ✅ **WORKING VERSION**: Always use the latest `.working_backup_*` file if something breaks
- ⚠️ **DO NOT USE**: `ContentView.swift.small` - This was the original Cal AI app but is now outdated
- ⚠️ **DO NOT USE**: `ContentView.swift.backup` - Old version with duplicates and errors

## 📋 Main Components in ContentView.swift

### 1. **Services & Utilities** (Lines 1-3640)
- `PendingMetaEventService` - Meta/Facebook event tracking
- `SerpAPIService` - Market data API service
- `MarketDataCacheService` - Cache for API responses
- `ThriftStoreMapService` - Map location services
- `LocationManager` - User location tracking
- **Manager Classes** (Lines 3118-3640):
  - `GlobalLoopSettings`
  - `GlobalAudioManager`
  - `AudioManager`
  - `SharedInstrumentalManager`
  - `AudioFilePicker`

### 2. **Authentication & Sign In** (Lines 1917-2772)
- `AppleSignInButton`
- `GoogleSignInButton`
- `EmailSignInButton`
- `SignInView`
- `EmailSignInView` (with code verification)
- `TermsOfServiceView`
- `PrivacyPolicyView`

### 3. **Onboarding Flow** (Lines 3917-8166)
All 34 onboarding steps including:
- `RatingView`
- `CompletionView`
- `ProgressGraphView`
- `UltimateGoalView`
- `ObstaclesView`
- `CalAIComparisonView` (formerly ThriftingTransition)
- `GenderSelectionView`
- `SongFrequencyView` (first screen for anonymous users)
- `HeightWeightView`
- `BirthdateView`
- `GoalSelectionView`
- `DesiredWeightView`
- And many more...

### 4. **Main App Navigation** (Lines 8958-9220)
- `ContentView` - Welcome/landing screen (shows when not logged in)
- `PaywallResumeView`
- `FirstTimeCongratsPopup`
- `OnboardingView` - Onboarding wrapper for logged-in users

### 5. **Subscription & Paywall** (Lines 10450-11344)
- `SubscriptionView` - Main subscription screen
- `WinbackView` - Winback offer when user cancels
- `OneTimeOfferView`
- `CreateAccountView` - Shows ONLY if user not logged in after purchase

### 6. **Data Models & Managers** (Lines 11988-12750)
- `UserData` struct:
  - Properties: `id`, `email`, `name`, `profileImageURL`, `authProvider`
- `RemoteConfigManager` - Feature flags from Firestore
- `AuthenticationManager` (Lines 12105-12750):
  - Main auth manager with `shared` singleton
  - Properties: `isLoggedIn`, `currentUser`, `hasCompletedOnboarding`, `hasCompletedSubscription`
  - Methods: 
    - `signInWithApple()`
    - `signInWithGoogle()`
    - `signInWithEmail()`
    - `logOut()` ⚠️ Note: NOT `signOut()`
    - `markOnboardingCompleted()`
    - `markSubscriptionCompleted()`

### 7. **Cal AI Main App** (Lines 12352-14684)
- **`MainAppView`** - Root view of Cal AI app (shows after login + subscription)
  - Tab-based interface with:
    - `HomeView` - Main dashboard with calorie tracking
    - `ProgressView` - Progress tracking
    - `ProfileView` - User profile (uses `authManager.currentUser`, NOT `.user`)
- Supporting components:
  - `MacroCard`
  - `TabButton`
  - `DashedCircle`
  - `FoodScanFlow`
  - `FoodDatabaseView`

### 8. **Utilities & Helpers** (Lines 14685-15998)
- `ImagePicker` - Photo picker for profile
- `TimePickerButton` - Time selection UI
- `ToolDetailView` - Tool detail screens
- Various helper structs and extensions

## 🔄 App Flow

```
App Launch (InvoiceApp.swift)
    ↓
Checks: isLoggedIn && hasCompletedSubscription?
    ├─ YES → MainAppView (Cal AI food tracking)
    └─ NO → ContentView (Welcome screen)
              ↓
         User taps "Sign In" or "Get Started"
              ↓
         ┌─────────────┬─────────────┐
         │             │             │
    Sign In    Get Started    Continue
         │             │             │
         ↓             ↓             ↓
    Auth Flow    SongFrequencyView   Email
         │          (Anon)           Verify
         └─────────────┴─────────────┘
                      ↓
              Onboarding Flow (34 steps)
                      ↓
              SubscriptionView
                      ↓
         hasCompletedSubscription = true
                      ↓
              MainAppView (Cal AI)
```

## 🚨 Common Pitfalls to Avoid

### 1. **Duplicate Declarations**
- ❌ NEVER have two `struct HomeView`
- ❌ NEVER have two `struct ProfileView`
- ❌ NEVER have two `struct ImagePicker`
- ✅ Each struct/class should appear only ONCE in ContentView.swift

### 2. **Property Names**
- ✅ `authManager.currentUser` (correct)
- ❌ `authManager.user` (wrong - doesn't exist)
- ✅ `user.name` (correct - UserData property)
- ❌ `user.displayName` (wrong - doesn't exist in UserData)
- ✅ `authManager.logOut()` (correct method)
- ❌ `authManager.signOut()` (wrong - doesn't exist)

### 3. **File Management**
- ✅ ALWAYS create a timestamped backup before major changes
- ✅ Use `ContentView.swift.working_backup_*` files for recovery
- ❌ DON'T merge code from `ContentView.swift.small` - it's outdated
- ❌ DON'T use old `.backup` or `.bak` files

## 🛠️ Making Changes Safely

### Before Making Changes:
```bash
# Create a backup
cp Invoice/ContentView.swift Invoice/ContentView.swift.safe_$(date +%Y%m%d_%H%M%S)
```

### If Something Breaks:
```bash
# List all backups
ls -lht Invoice/ContentView.swift* | head -10

# Restore from latest working backup
cp Invoice/ContentView.swift.working_backup_20260114_140241 Invoice/ContentView.swift
```

### Verify No Errors:
- Check for duplicate struct declarations
- Check for missing closing braces
- Verify all property names match their structs
- Run linter to catch issues

## 📊 Key Metrics

- **Total Lines:** 15,999
- **Main Components:** 100+
- **Onboarding Steps:** 34
- **Auth Methods:** 3 (Apple, Google, Email)
- **Main App Views:** 3 (Home, Progress, Profile)

## 🎯 Next Steps for Better Organization

**Recommended:** Split ContentView.swift into separate files:
1. `Views/Authentication/` - Auth views
2. `Views/Onboarding/` - Onboarding flow
3. `Views/MainApp/` - Cal AI main app
4. `Managers/` - All manager classes
5. `Services/` - API services
6. `Models/` - Data models

This would prevent the "lost code" issue by making each component independent and easier to track.

---

**✅ Current Status:** App is fully functional with no errors
**📁 Backup Location:** `ContentView.swift.working_backup_20260114_140241`
**⏰ Last Verified:** January 14, 2026 at 2:02 PM
