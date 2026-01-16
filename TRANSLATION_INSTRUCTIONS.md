# 🤖 Auto-Translate All Strings

## ⚡ Quick Start (5 Minutes)

### Step 1: Install Python Package

Open Terminal in your project folder:

```bash
cd /Users/kaleb/Desktop/invoice
pip3 install deep-translator
```

### Step 2: Run the Script

```bash
python3 auto_translate_xcstrings.py
```

That's it! The script will:
- ✅ Create a backup of your current file
- ✅ Translate all 1,500+ empty strings
- ✅ Add Spanish and Russian translations
- ✅ Skip strings that are already translated
- ✅ Skip symbols, emojis, numbers (don't need translation)

Takes ~5-10 minutes to complete.

---

## 🎯 What the Script Does

1. **Reads** `Invoice/Localizable.xcstrings`
2. **Finds** all strings without Spanish/Russian translations
3. **Translates** using Google Translate (free, no API key needed)
4. **Saves** back to the file
5. **Creates backup** at `Invoice/Localizable.xcstrings.backup`

---

## 📊 Expected Output

```
🌐 Auto-Translate Localizable.xcstrings
==================================================
✅ Backup created: Invoice/Localizable.xcstrings.backup
📖 Loading Invoice/Localizable.xcstrings...
📊 Found 1500 strings

[1/1500] Processing: Profile...
   🇪🇸 Translating to Spanish...
   ✅ Spanish: Perfil
   🇷🇺 Translating to Russian...
   ✅ Russian: Профиль

[2/1500] Processing: Weight Progress...
   🇪🇸 Translating to Spanish...
   ✅ Spanish: Progreso de peso
   ...

==================================================
📊 TRANSLATION SUMMARY
==================================================
Total strings: 1500
Skipped: 300
Spanish translated: 1150
Russian translated: 1150
Errors: 0

✅ Done! Check Invoice/Localizable.xcstrings
```

---

## 🧪 Test After Translation

1. **Build and run** your app (⌘R)
2. **Go to Profile → Language → Spanish**
3. **Restart app**
4. **Everything should be in Spanish!** 🇪🇸
5. **Try Russian** to verify both languages work

---

## ⚠️ Important Notes

### Translation Quality
- Uses **Google Translate** (free, no API key)
- Quality is **good for 95% of strings**
- You may want to **manually review**:
  - Brand names ("Cal AI" should stay "Cal AI")
  - Technical terms
  - Marketing copy
  - Button labels (verify they fit in UI)

### What Gets Skipped
The script intelligently skips:
- ✅ Empty strings
- ✅ Single characters (. , ! ?)
- ✅ Numbers (123, 50%)
- ✅ Emojis (🎉 🔥 ✨)
- ✅ URLs (https://...)
- ✅ Email addresses
- ✅ Already translated strings

### Backup
- **Automatic backup** created at `Invoice/Localizable.xcstrings.backup`
- If something goes wrong: `mv Invoice/Localizable.xcstrings.backup Invoice/Localizable.xcstrings`

---

## 🔧 Troubleshooting

### Error: "deep_translator not installed"
```bash
pip3 install deep-translator
```

### Error: "No module named 'deep_translator'"
Try with full path:
```bash
python3 -m pip install deep-translator
```

### Script runs but no translations appear
- Check that `Invoice/Localizable.xcstrings` exists
- Make sure you're in the project root folder
- Look for error messages in the output

### Translations look weird
- This is normal - some strings need context
- You can manually fix important ones in Xcode after
- Open `Localizable.xcstrings` in Xcode and edit

---

## 🎨 After Auto-Translation

### 1. Review Key Strings (Optional but Recommended)
Open Xcode → `Localizable.xcstrings` → Check these:
- App name
- Tab bar labels
- Main buttons
- Marketing copy

### 2. Test All Languages
- Build and run app
- Test Spanish thoroughly
- Test Russian thoroughly
- Check for:
  - Text overflow (Spanish/Russian are longer)
  - Weird translations
  - Missing translations

### 3. Manual Fixes (If Needed)
In Xcode's String Catalog editor:
- Find odd translations
- Click the cell
- Type better translation
- Save

---

## 🆚 Alternative: Professional Translation Services

If you want **human-quality** translations:

### Option 1: Lokalise (Recommended)
- Cloud TMS with GitHub integration
- Mix of machine + human translation
- ~$50-100 for 1,500 strings
- Sign up: https://lokalise.com

### Option 2: DeepL Pro
- Better than Google Translate
- API costs ~$20/month
- Can modify script to use DeepL instead
- Sign up: https://www.deepl.com/pro-api

### Option 3: Manual Translation
- Hire freelancer on Fiverr/Upwork
- Native Spanish + Russian speakers
- ~$100-200 for professional quality
- Takes 1-2 days

---

## 📝 Script Modifications

### Use DeepL Instead of Google Translate

Install DeepL:
```bash
pip3 install deepl
```

Modify script (line 24):
```python
from deepl import Translator
translator = Translator("YOUR_API_KEY")
```

### Skip Specific Strings

Add to `should_skip_translation()` function:
```python
# Skip brand name
if "Cal AI" in value or "Thrifty" in value:
    return True
```

---

## ✅ Summary

**Fastest**: Run `python3 auto_translate_xcstrings.py` (5 minutes, free)

**Best Quality**: Use Lokalise or hire translator ($50-200, 1-2 days)

**Middle Ground**: Use script + manually review key strings (30 minutes)

---

**Ready? Run the script and watch your app become multilingual!** 🌍

```bash
python3 auto_translate_xcstrings.py
```
