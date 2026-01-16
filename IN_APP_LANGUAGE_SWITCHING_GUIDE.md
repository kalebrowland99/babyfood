# 🌐 In-App Language Switching - Complete Guide

## ✅ What's Been Implemented

Your app now supports **in-app language switching** where users can choose their preferred language (English, Spanish, Russian) directly from the Profile/Settings tab, independent of device language settings!

---

## 📦 Files Created

### 1. **LanguageManager.swift**
- Core service that manages language selection
- Stores user preference in UserDefaults
- Provides `@Published` observable for SwiftUI
- Auto-detects device language on first launch

### 2. **LanguagePickerView.swift**
- Beautiful UI component for your Profile/Settings tab
- Shows current language with flag emoji 🇺🇸 🇪🇸 🇷🇺
- Opens modal sheet with all language options
- Includes haptic feedback and smooth animations

### 3. **Updated Localizable.xcstrings**
- Added 8 new language-related strings
- All translated to English, Spanish, Russian

### 4. **Updated InvoiceApp.swift**
- Integrated LanguageManager
- App respects selected language on launch

---

## 🚀 How to Add to Your Profile Tab

### Simple Integration (2 minutes)

In your Settings/Profile view, add this anywhere in your List:

```swift
import SwiftUI

struct ProfileView: View {
    var body: some View {
        List {
            // Your existing profile sections...
            
            Section {
                LanguagePickerView()
            } header: {
                Text("Preferences")
            }
            
            // More sections...
        }
        .navigationTitle("Profile")
    }
}
```

**That's it!** The `LanguagePickerView` is a complete, ready-to-use component.

---

## 🎨 What Users Will See

### In Profile Tab:
```
┌─────────────────────────────────┐
│ Language           🇺🇸 English › │
└─────────────────────────────────┘
```

### When Tapped - Language Selection Sheet:

```
┌─────────────────────────────────┐
│           Language              │
│                                 │
│ Select Language                 │
│                                 │
│  🇺🇸  English          ✓        │
│      English                    │
│                                 │
│  🇪🇸  Español                   │
│      Spanish                    │
│                                 │
│  🇷🇺  Русский                   │
│      Russian                    │
│                                 │
│ The app will restart to apply   │
│ the new language.               │
└─────────────────────────────────┘
```

---

## 🔄 How Language Changes Work

### User Flow:

1. User taps "Language" in Profile tab
2. Beautiful sheet opens with 3 language options
3. User selects new language (e.g., Spanish)
4. Haptic feedback confirms selection
5. Alert appears: "Language Changed - Please restart the app"
6. User chooses "Restart Now" or "Later"
7. App restarts with new language applied!

### Technical Flow:

```
User selects language
    ↓
LanguageManager.changeLanguage()
    ↓
Save to UserDefaults
    ↓
Update AppleLanguages preference
    ↓
Post notification
    ↓
Alert user to restart
    ↓
App relaunches with new language
```

---

## 💻 Usage Examples

### Basic - In Profile Tab

```swift
Section("Settings") {
    LanguagePickerView()
    // Other settings...
}
```

### With Custom Styling

```swift
Section {
    LanguagePickerView()
        .listRowBackground(Color(.systemGray6))
} header: {
    Text("App Settings")
} footer: {
    Text("Change the language used throughout the app")
        .font(.caption)
}
```

### Get Current Language in Code

```swift
import SwiftUI

struct SomeView: View {
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        VStack {
            Text("Current language: \(languageManager.currentLanguage.name)")
            Text("Flag: \(languageManager.currentLanguage.flag)")
            Text("Code: \(languageManager.currentLanguage.code)")
        }
    }
}
```

### Programmatically Change Language

```swift
// Switch to Spanish
LanguageManager.shared.changeLanguage(to: .spanish)

// Switch to Russian
LanguageManager.shared.changeLanguage(to: .russian)

// Switch to English
LanguageManager.shared.changeLanguage(to: .english)
```

---

## 🎯 Example: Full Profile/Settings View

Here's a complete example of how your Profile tab might look:

```swift
import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationView {
            List {
                // User Info Section
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("John Doe")
                                .font(.headline)
                            Text("john@example.com")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // App Settings Section
                Section("settings") {
                    // Language Picker - This is what you add!
                    LanguagePickerView()
                    
                    NavigationLink {
                        Text("Notifications")
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                    
                    NavigationLink {
                        Text("Privacy")
                    } label: {
                        Label("Privacy", systemImage: "lock")
                    }
                }
                
                // Account Section
                Section("account") {
                    NavigationLink {
                        Text("Subscription")
                    } label: {
                        Label("subscription", systemImage: "creditcard")
                    }
                    
                    Button(role: .destructive) {
                        // Logout
                    } label: {
                        Label("logout", systemImage: "arrow.right.square")
                    }
                }
            }
            .navigationTitle("profile")
        }
    }
}
```

---

## 🧪 Testing

### Test Language Switching:

1. Run your app
2. Navigate to Profile/Settings tab
3. Tap "Language"
4. Select "Español" (Spanish)
5. Tap "Restart Now" in the alert
6. App restarts - verify all UI is now in Spanish!
7. Repeat with Russian to test Cyrillic script

### Test Each Language:

**English** → Language → English → Done  
**Spanish** → Idioma → Español → Hecho  
**Russian** → Язык → Русский → Готово

---

## 🎨 Customization Options

### Change Button Style

Edit `LanguagePickerView.swift` to customize the button appearance:

```swift
Button(action: { showLanguageSheet = true }) {
    HStack {
        Label("language", systemImage: "globe")  // Add icon
        Spacer()
        Text(languageManager.currentLanguage.name)
            .foregroundColor(.blue)  // Change color
            .fontWeight(.semibold)   // Make bold
    }
}
```

### Add More Languages

To add more languages later:

1. Add to `AppLanguage` enum in `LanguageManager.swift`:
```swift
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"
    case russian = "ru"
    case french = "fr"     // NEW!
    case german = "de"     // NEW!
    
    var name: String {
        switch self {
        case .french: return "Français"
        case .german: return "Deutsch"
        // ...
        }
    }
    
    var flag: String {
        switch self {
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        // ...
        }
    }
}
```

2. Add translations to `Localizable.xcstrings`
3. Add localization in Xcode project settings

---

## 🔧 Advanced: Listen to Language Changes

If you need to update specific views when language changes:

```swift
struct MyView: View {
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        Text("welcome")
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // Language changed - update your view if needed
                print("Language changed to: \(languageManager.currentLanguage.name)")
            }
    }
}
```

---

## 🌟 Features Included

✅ **Flag Emojis** - Beautiful visual language indicators (🇺🇸 🇪🇸 🇷🇺)  
✅ **Native Names** - Shows languages in their native script  
✅ **English Names** - Subtitle showing English name for clarity  
✅ **Checkmark** - Visual indication of currently selected language  
✅ **Haptic Feedback** - Satisfying tap feedback when selecting  
✅ **Smooth Animations** - Polished transitions and selections  
✅ **Restart Alert** - Clear user communication about app restart  
✅ **Persistence** - User selection saved across app launches  
✅ **Auto-Detection** - First launch detects device language  

---

## 🚨 Important Notes

### App Restart Required

When a user changes language, the app needs to restart for changes to fully apply. This is normal iOS behavior and ensures:
- All views update correctly
- System components (date pickers, alerts) use new language
- No weird half-translated states

### Alternative: Manual Restart

If you prefer users restart manually:

In `LanguagePickerView.swift`, remove the automatic restart and just show a message:

```swift
private func showRestartAlert() {
    let alert = UIAlertController(
        title: NSLocalizedString("language_changed", comment: ""),
        message: NSLocalizedString("restart_app_message", comment: ""),
        preferredStyle: .alert
    )
    
    alert.addAction(UIAlertAction(
        title: NSLocalizedString("ok", comment: ""),
        style: .default
    ) { _ in
        dismiss()
    })
    
    // Present alert
}
```

Users then manually close and reopen the app.

---

## 📊 Testing Checklist

- [ ] Language picker appears in Profile/Settings tab
- [ ] Tapping opens language selection sheet
- [ ] All 3 languages (English, Spanish, Russian) are shown
- [ ] Current language has checkmark
- [ ] Flags display correctly
- [ ] Selecting Spanish changes to Spanish
- [ ] Selecting Russian shows Cyrillic text correctly
- [ ] Alert appears after selection
- [ ] App restarts and new language is applied
- [ ] Language preference persists after app restart
- [ ] All UI elements are translated (that use String Catalog keys)

---

## 🎯 Next Steps

1. **Add to Profile Tab** - Copy the example code above
2. **Test It** - Try switching between all 3 languages
3. **Start Localizing** - Replace hardcoded strings in your app:
   - Change `Text("Welcome")` to `Text("welcome")`
   - Change `Button("Save")` to `Button("save")`
   - Use keys from `Localizable.xcstrings`

4. **Add More Strings** - Use `COMMON_INVOICE_STRINGS.md` as reference

---

## 💡 Pro Tips

### 1. Test with Long Text
Russian and Spanish text can be 15-25% longer than English. Make sure your layouts are flexible:

```swift
Text("some_text")
    .lineLimit(nil)  // Allow multiple lines
    .minimumScaleFactor(0.8)  // Shrink if needed
```

### 2. Use Environment Locale
For date/number formatting:

```swift
Text(date, style: .date)  // Automatically uses current language's format
```

### 3. Test All Screens
After implementing localization, test every screen in all 3 languages to ensure:
- Text doesn't overflow
- Buttons fit
- Navigation titles display correctly

---

## 🆘 Troubleshooting

### Issue: Language picker not showing
**Solution**: Make sure you imported SwiftUI and the file is added to your Xcode project target.

### Issue: Translations not changing
**Solution**: 
1. Verify you're using `Text("key")` not `Text("Hardcoded String")`
2. Check the key exists in `Localizable.xcstrings`
3. Make sure app restarts after language change

### Issue: Russian characters showing as boxes
**Solution**: Ensure your SF Pro font is being used (default in SwiftUI). If using custom fonts, verify they support Cyrillic.

### Issue: App not restarting
**Solution**: The restart notification triggers view refresh. For a hard restart, users can manually close and reopen the app.

---

## 🎉 You're All Set!

Your app now has professional in-app language switching with:
- 🇺🇸 English
- 🇪🇸 Spanish (Español)
- 🇷🇺 Russian (Русский)

Users can switch languages anytime from the Profile tab, making your app accessible to Spanish and Russian speakers worldwide! 🌍

---

**Need Help?** Check the code comments in `LanguageManager.swift` and `LanguagePickerView.swift` for detailed explanations.
