# Cal AI - Quick Reference Guide

## 🚀 Before You Start Coding

**ALWAYS create a backup first:**
```bash
./backup.sh
```

## 🔍 Common Issues & Quick Fixes

### Issue: "Cannot find 'X' in scope"

**Likely Cause:** Missing component or manager class

**Fix:**
1. Check if struct/class exists: `grep -n "^struct X\|^class X" Invoice/ContentView.swift`
2. If missing, restore from backup: `cp Invoice/ContentView.swift.working_backup_20260114_140241 Invoice/ContentView.swift`

---

### Issue: "Invalid redeclaration of 'X'"

**Likely Cause:** Duplicate struct/class declaration

**Fix:**
1. Find duplicates: `grep -n "^struct X" Invoice/ContentView.swift`
2. Remove the second occurrence (usually at the end of the file)
3. Keep the first one

**Common Duplicates:**
- `HomeView` - Keep around line 12536
- `ProfileView` - Keep around line 13127
- `ImagePicker` - Keep around line 14684

---

### Issue: "Value of type 'AuthenticationManager' has no member 'X'"

**Wrong Property Name → Correct Property Name:**
- ❌ `.user` → ✅ `.currentUser`
- ❌ `.signOut()` → ✅ `.logOut()`

**Fix:**
```bash
# Find and replace incorrect property
sed -i '' 's/authManager\.user/authManager.currentUser/g' Invoice/ContentView.swift
sed -i '' 's/authManager\.signOut/authManager.logOut/g' Invoice/ContentView.swift
```

---

### Issue: "Value of type 'UserData' has no member 'X'"

**Wrong Property Name → Correct Property Name:**
- ❌ `.displayName` → ✅ `.name`
- ❌ `.userName` → ✅ `.name`
- ❌ `.photo` → ✅ `.profileImageURL`

**UserData Properties (ONLY these exist):**
- `id: String`
- `email: String?`
- `name: String?`
- `profileImageURL: String?`
- `authProvider: AuthProvider`

---

### Issue: "Expected '}' in struct"

**Likely Cause:** Missing closing brace somewhere

**Fix:**
1. Check the line number in error
2. Look at the struct definition above that line
3. Count opening `{` and closing `}` - they should match
4. If can't find it, restore from backup

---

## 📝 Key Code Locations

**Need to modify authentication?**
→ Lines 12105-12750 (`AuthenticationManager`)

**Need to modify onboarding?**
→ Lines 3917-8166 (all onboarding views)

**Need to modify main app?**
→ Lines 12352-14684 (`MainAppView`, `HomeView`, `ProgressView`, `ProfileView`)

**Need to modify subscription/paywall?**
→ Lines 10450-11344 (`SubscriptionView`, `WinbackView`)

---

## 🔧 Useful Commands

### Create Backup
```bash
./backup.sh
```

### List All Backups
```bash
ls -lht Invoice/ContentView.swift* | head -10
```

### Restore from Backup
```bash
cp Invoice/ContentView.swift.backup_YYYYMMDD_HHMMSS Invoice/ContentView.swift
```

### Check Line Count
```bash
wc -l Invoice/ContentView.swift
```
**Expected:** ~15,999 lines

### Find a Struct/Class
```bash
grep -n "^struct YourStruct\|^class YourClass" Invoice/ContentView.swift
```

### Check for Duplicates
```bash
grep "^struct " Invoice/ContentView.swift | sort | uniq -d
```

### Verify No Errors
```bash
# Xcode will show errors in the Issue Navigator
# Or use the linter from command line
```

---

## 🎯 AuthenticationManager Quick Reference

### Properties (Read/Write)
- `isLoggedIn: Bool`
- `currentUser: UserData?`
- `hasCompletedOnboarding: Bool`
- `hasCompletedSubscription: Bool`
- `isLoading: Bool`
- `errorMessage: String?`

### Methods
- `signInWithApple()` - Sign in with Apple
- `signInWithGoogle()` - Sign in with Google
- `signInWithEmail(email: String, password: String)` - Email sign in
- `logOut()` - Log out user ⚠️ NOT signOut()
- `markOnboardingCompleted()` - Mark onboarding done
- `markSubscriptionCompleted()` - Mark subscription done

### Usage Example
```swift
@StateObject private var authManager = AuthenticationManager.shared

// Check if logged in
if authManager.isLoggedIn {
    // Show main app
}

// Get current user
if let user = authManager.currentUser {
    Text(user.name ?? "User")
}

// Log out
Button("Logout") {
    authManager.logOut()
}
```

---

## 🏗️ App Structure at a Glance

```
ContentView.swift (15,999 lines)
├── Services (1-3640)
│   ├── API Services
│   ├── Cache Services
│   └── Manager Classes
├── Authentication (1917-2772)
│   ├── Sign In Views
│   └── Terms/Privacy
├── Onboarding (3917-8166)
│   └── 34 onboarding steps
├── Main Navigation (8958-9220)
├── Subscription (10450-11344)
├── Data Models (11988-12750)
│   ├── UserData
│   └── AuthenticationManager
└── Cal AI Main App (12352-14684)
    ├── MainAppView
    ├── HomeView
    ├── ProgressView
    └── ProfileView
```

---

## ⚡ Emergency Recovery

**If everything is broken:**

1. **Stop and don't make more changes**
2. **Restore last known working version:**
   ```bash
   cp Invoice/ContentView.swift.working_backup_20260114_140241 Invoice/ContentView.swift
   ```
3. **Verify it works**
4. **Create a new backup:**
   ```bash
   ./backup.sh
   ```
5. **Try your changes again, one at a time**

---

**Last Updated:** January 14, 2026
**Working Version:** ContentView.swift.working_backup_20260114_140241
**Status:** ✅ All errors fixed, app is functional
