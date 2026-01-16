# 🔧 Xcode Setup Steps for Localization

## ⚠️ REQUIRED: Manual Steps in Xcode

These steps **MUST** be done in Xcode (cannot be automated):

---

## Step 1: Add Localizable.xcstrings to Project

1. Open `Invoice.xcodeproj` in Xcode
2. In the Project Navigator (left sidebar), right-click on the **Invoice** folder (the yellow folder, not the project at the top)
3. Select **"Add Files to 'Invoice'..."**
4. Navigate to the `Invoice` folder
5. Select `Localizable.xcstrings`
6. In the dialog that appears:
   - ✅ Make sure **"Add to targets: Invoice"** is checked
   - ✅ **UNCHECK** "Copy items if needed" (file is already in correct location)
   - ✅ "Create groups" should be selected
7. Click **"Add"**

**Verify**: You should now see `Localizable.xcstrings` in the Invoice folder in Xcode's Project Navigator.

---

## Step 2: Configure Project Localizations

1. In Xcode, click on the **Project** (blue icon at the very top of the navigator)
2. Make sure **"Invoice"** is selected under TARGETS (not PROJECT)
3. Click on the **"Info"** tab at the top
4. Scroll down to find the **"Localizations"** section
5. You should see **"English - Development Language"** listed

### Add Spanish:
1. Click the **+** button under Localizations
2. Select **"Spanish (es)"** from the dropdown
3. A dialog will appear showing files to localize
4. Make sure `Localizable.xcstrings` is **checked**
5. Click **"Finish"**

### Add Russian:
1. Click the **+** button again
2. Select **"Russian (ru)"** from the dropdown
3. Again, make sure `Localizable.xcstrings` is **checked**
4. Click **"Finish"**

**Verify**: You should now see:
- English - Development Language
- Spanish (es)
- Russian (ru)

---

## Step 3: Verify String Catalog Setup

1. In Project Navigator, click on `Localizable.xcstrings`
2. You should see a nice table view with:
   - Left column: String keys (welcome, invoice, save, etc.)
   - Three columns: English, Spanish, Russian
   - All translations visible

**This is your translation editor!**

---

## Step 4: Test Localization

### Option A: Change Simulator Language
1. Run your app in the Simulator
2. Go to Settings → General → Language & Region
3. Change "iPhone Language" to "Español" or "Русский"
4. Your app will restart in that language

### Option B: Use Xcode Scheme (Faster)
1. In Xcode, go to **Product → Scheme → Edit Scheme...**
2. Select **"Run"** in the left sidebar
3. Click on the **"Options"** tab
4. Under "App Language", select:
   - **Spanish** to test Spanish
   - **Russian** to test Russian
5. Click **"Close"**
6. Run your app - it will launch in the selected language

---

## Step 5: Start Localizing Your Code

### Example: Updating a Simple Text View

**Before (hardcoded):**
```swift
Text("Welcome")
```

**After (localized):**
```swift
Text("welcome")
```

That's it! SwiftUI automatically looks up "welcome" in your String Catalog.

### Example: Updating a Button

**Before:**
```swift
Button("Save") {
    // action
}
```

**After:**
```swift
Button("save") {
    // action
}
```

---

## 🎯 Quick Test Example

Try this in your `ContentView.swift` to test:

```swift
VStack {
    Text("welcome")
        .font(.largeTitle)
    
    Text("invoice")
        .font(.title)
    
    Button("save") {
        print("Save tapped")
    }
    .buttonStyle(.borderedProminent)
    
    Button("cancel") {
        print("Cancel tapped")
    }
}
```

Now run the app with different languages using the scheme editor method above!

---

## 📱 What Your Users Will See

- **English users**: Welcome, Invoice, Save, Cancel
- **Spanish users**: Bienvenido, Factura, Guardar, Cancelar
- **Russian users**: Добро пожаловать, Счёт, Сохранить, Отмена

The app automatically detects the device language and shows the right translations!

---

## 🔍 Common Issues & Solutions

### Issue: Strings not translating
**Solution**: Make sure you used the exact key name from Localizable.xcstrings (case-sensitive!)

### Issue: File not found in Xcode
**Solution**: The file must be added to the Xcode project (Step 1). Simply having it in the folder isn't enough.

### Issue: Translations not showing in table view
**Solution**: Make sure you added the localizations in Project → Info → Localizations (Step 2)

### Issue: App still in English after changing language
**Solution**: 
1. Make sure you're using `Text("key")` not `Text("Hardcoded String")`
2. Kill and restart the app after changing system language
3. Check that the key exists in Localizable.xcstrings

---

## ✅ Checklist

Complete these steps in order:

- [ ] Step 1: Add Localizable.xcstrings to Xcode project
- [ ] Step 2: Add Spanish localization in Project Info
- [ ] Step 3: Add Russian localization in Project Info
- [ ] Step 4: Open Localizable.xcstrings in Xcode - verify table view shows
- [ ] Step 5: Edit scheme to test Spanish
- [ ] Step 6: Run app - verify Spanish works
- [ ] Step 7: Edit scheme to test Russian
- [ ] Step 8: Run app - verify Russian works
- [ ] Step 9: Start replacing hardcoded strings in ContentView.swift

---

## 🚀 You're Ready!

Once you've completed these steps, your app will support:
- 🇺🇸 English (default)
- 🇪🇸 Spanish
- 🇷🇺 Russian

Users will automatically see the app in their device language, and RevenueCat's paywall will also automatically localize to match!

---

**Next**: See `LOCALIZATION_GUIDE.md` for details on adding more translations and advanced features.
