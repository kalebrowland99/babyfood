#!/usr/bin/env python3
"""
Auto-translate empty strings in Localizable.xcstrings
Translates English → Spanish & Russian using Google Translate
"""

import json
import time
from pathlib import Path

try:
    from deep_translator import GoogleTranslator
except ImportError:
    print("❌ Error: deep_translator not installed")
    print("Run: pip3 install deep-translator")
    exit(1)

# Configuration
XCSTRINGS_PATH = Path("Invoice/Localizable.xcstrings")
BACKUP_PATH = Path("Invoice/Localizable.xcstrings.backup")

# Target languages
LANGUAGES = {
    "es": "Spanish",
    "ru": "Russian"
}

def load_xcstrings():
    """Load the xcstrings JSON file"""
    with open(XCSTRINGS_PATH, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_xcstrings(data):
    """Save the xcstrings JSON file"""
    with open(XCSTRINGS_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def create_backup():
    """Create backup of original file"""
    import shutil
    shutil.copy2(XCSTRINGS_PATH, BACKUP_PATH)
    print(f"✅ Backup created: {BACKUP_PATH}")

def translate_text(text, target_lang):
    """Translate text using Google Translate"""
    try:
        translator = GoogleTranslator(source='en', target=target_lang)
        translated = translator.translate(text)
        time.sleep(0.1)  # Rate limiting - be nice to Google
        return translated
    except Exception as e:
        print(f"   ⚠️ Translation error: {e}")
        return None

def needs_translation(string_data, lang):
    """Check if a string needs translation for given language"""
    if "localizations" not in string_data:
        return True
    
    localizations = string_data["localizations"]
    
    # Check if language exists and has a value
    if lang not in localizations:
        return True
    
    if "stringUnit" not in localizations[lang]:
        return True
    
    if "value" not in localizations[lang]["stringUnit"]:
        return True
    
    value = localizations[lang]["stringUnit"]["value"]
    return not value or value.strip() == ""

def get_english_value(string_data, key):
    """Extract English value from string data"""
    # Try to get from localizations
    if "localizations" in string_data and "en" in string_data["localizations"]:
        en_data = string_data["localizations"]["en"]
        if "stringUnit" in en_data and "value" in en_data["stringUnit"]:
            return en_data["stringUnit"]["value"]
    
    # If no English localization exists, use the key itself as the English text
    # This is common in String Catalogs - the key IS the English string
    return key

def should_skip_translation(key, value):
    """Determine if a string should be skipped"""
    # Skip empty strings
    if not value or value.strip() == "":
        return True
    
    # Skip very long legal text (>500 characters is probably legal/TOS)
    if len(value) > 500:
        return True
    
    # Skip single pure symbols/emojis only (not alphanumeric)
    if len(value) <= 2 and all(not c.isalnum() for c in value):
        return True
    
    # Skip pure numbers only (but allow "50% OFF", "$79.99", etc. with words)
    stripped = value.replace(".", "").replace(",", "").replace("%", "").replace("$", "").replace(" ", "").strip()
    if stripped.isdigit() and len(value) < 10:
        return True
    
    # Skip URLs
    if "http://" in value or "https://" in value:
        return True
    
    # Skip email addresses (full format)
    if "@" in value and "." in value and " " not in value:
        return True
    
    return False

def main():
    print("🌐 Auto-Translate Localizable.xcstrings")
    print("=" * 50)
    
    # Check if file exists
    if not XCSTRINGS_PATH.exists():
        print(f"❌ Error: {XCSTRINGS_PATH} not found")
        return
    
    # Create backup
    create_backup()
    
    # Load data
    print(f"📖 Loading {XCSTRINGS_PATH}...")
    data = load_xcstrings()
    
    if "strings" not in data:
        print("❌ Error: Invalid xcstrings format")
        return
    
    strings = data["strings"]
    total_strings = len(strings)
    
    print(f"📊 Found {total_strings} strings")
    print()
    
    # Count what needs translation
    stats = {
        "total": total_strings,
        "skipped": 0,
        "es_translated": 0,
        "ru_translated": 0,
        "es_already": 0,
        "ru_already": 0,
        "errors": 0
    }
    
    # Process each string
    for idx, (key, string_data) in enumerate(strings.items(), 1):
        print(f"[{idx}/{total_strings}] Processing: {key[:50]}...")
        
        # Get English value (uses key if no explicit English localization)
        en_value = get_english_value(string_data, key)
        
        # Skip if should skip
        if should_skip_translation(key, en_value):
            print(f"   ⏭️  Skipped (no content or special case)")
            stats["skipped"] += 1
            continue
        
        # Initialize localizations if needed
        if "localizations" not in string_data:
            string_data["localizations"] = {}
        
        localizations = string_data["localizations"]
        
        # Ensure English exists
        if "en" not in localizations:
            localizations["en"] = {
                "stringUnit": {
                    "state": "translated",
                    "value": en_value
                }
            }
        
        # Translate to Spanish
        if needs_translation(string_data, "es"):
            print(f"   🇪🇸 Translating to Spanish...")
            es_value = translate_text(en_value, "es")
            
            if es_value:
                localizations["es"] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": es_value
                    }
                }
                stats["es_translated"] += 1
                print(f"   ✅ Spanish: {es_value[:60]}")
            else:
                stats["errors"] += 1
        else:
            stats["es_already"] += 1
            print(f"   ✓ Spanish already exists")
        
        # Translate to Russian
        if needs_translation(string_data, "ru"):
            print(f"   🇷🇺 Translating to Russian...")
            ru_value = translate_text(en_value, "ru")
            
            if ru_value:
                localizations["ru"] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": ru_value
                    }
                }
                stats["ru_translated"] += 1
                print(f"   ✅ Russian: {ru_value[:60]}")
            else:
                stats["errors"] += 1
        else:
            stats["ru_already"] += 1
            print(f"   ✓ Russian already exists")
        
        print()
    
    # Save updated file
    print("💾 Saving translations...")
    save_xcstrings(data)
    
    # Print summary
    print()
    print("=" * 50)
    print("📊 TRANSLATION SUMMARY")
    print("=" * 50)
    print(f"Total strings: {stats['total']}")
    print(f"Skipped: {stats['skipped']}")
    print(f"Spanish translated: {stats['es_translated']}")
    print(f"Spanish already existed: {stats['es_already']}")
    print(f"Russian translated: {stats['ru_translated']}")
    print(f"Russian already existed: {stats['ru_already']}")
    print(f"Errors: {stats['errors']}")
    print()
    print(f"✅ Done! Check {XCSTRINGS_PATH}")
    print(f"📁 Backup saved at: {BACKUP_PATH}")

if __name__ == "__main__":
    main()
