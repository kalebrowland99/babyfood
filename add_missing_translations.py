#!/usr/bin/env python3
"""
Add specific missing translations to Localizable.xcstrings
"""

import json
from pathlib import Path

XCSTRINGS_PATH = Path("Invoice/Localizable.xcstrings")

# Missing translations to add
MISSING_TRANSLATIONS = {
    "Protein": {
        "en": "Protein",
        "es": "Proteína",
        "ru": "Белок"
    },
    "Carbs": {
        "en": "Carbs",
        "es": "Carbohidratos",
        "ru": "Углеводы"
    },
    "Fats": {
        "en": "Fats",
        "es": "Grasas",
        "ru": "Жиры"
    },
    "Fiber": {
        "en": "Fiber",
        "es": "Fibra",
        "ru": "Клетчатка"
    },
    "Sugar": {
        "en": "Sugar",
        "es": "Azúcar",
        "ru": "Сахар"
    },
    "Sodium": {
        "en": "Sodium",
        "es": "Sodio",
        "ru": "Натрий"
    },
    "Terms of Service": {
        "en": "Terms of Service",
        "es": "Términos de servicio",
        "ru": "Условия использования"
    },
    "Privacy Policy": {
        "en": "Privacy Policy",
        "es": "Política de privacidad",
        "ru": "Политика конфиденциальности"
    },
    "Home": {
        "en": "Home",
        "es": "Inicio",
        "ru": "Главная"
    },
    "📧 By email: helpthrifty@gmail.com": {
        "en": "📧 By email: helpthrifty@gmail.com",
        "es": "📧 Por correo: helpthrifty@gmail.com",
        "ru": "📧 Email: helpthrifty@gmail.com"
    }
}

def main():
    print("🔧 Adding missing translations...")
    
    # Load current file
    with open(XCSTRINGS_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    strings = data.get("strings", {})
    added = 0
    updated = 0
    
    for key, translations in MISSING_TRANSLATIONS.items():
        if key not in strings:
            # Add new entry
            strings[key] = {
                "localizations": {}
            }
            added += 1
        
        # Ensure localizations exist
        if "localizations" not in strings[key]:
            strings[key]["localizations"] = {}
        
        localizations = strings[key]["localizations"]
        
        # Add each language
        for lang, value in translations.items():
            if lang not in localizations or not localizations.get(lang, {}).get("stringUnit", {}).get("value"):
                localizations[lang] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": value
                    }
                }
                updated += 1
                print(f"   ✅ Added {lang}: {key} = {value}")
    
    # Save
    with open(XCSTRINGS_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Done! Added {added} new entries, updated {updated} translations")

if __name__ == "__main__":
    main()
