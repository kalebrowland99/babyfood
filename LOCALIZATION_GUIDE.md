# 🌍 Localization Guide - String Catalogs

## Overview
This app supports **English** (base), **Spanish**, and **Russian** using Apple's modern String Catalogs (.xcstrings).

---

## 📁 File Location
- **String Catalog**: `Invoice/Localizable.xcstrings`
- **Supported Languages**: 
  - 🇺🇸 English (en) - Base language
  - 🇪🇸 Spanish (es)
  - 🇷🇺 Russian (ru)

---

## 🔧 Setup Instructions

### 1. Add Localizable.xcstrings to Xcode Project

**IMPORTANT**: You must add this file to your Xcode project:

1. Open Xcode
2. Right-click on the `Invoice` folder in the Project Navigator
3. Select "Add Files to 'Invoice'..."
4. Navigate to `Invoice/Localizable.xcstrings`
5. Make sure "Copy items if needed" is **unchecked** (file is already in the right place)
6. Make sure "Add to targets: Invoice" is **checked**
7. Click "Add"

### 2. Configure Project Localizations

1. In Xcode, select your project (top of navigator)
2. Select the "Invoice" target
3. Go to the "Info" tab
4. Under "Localizations", click the **+** button
5. Add **Spanish (es)** 
6. Add **Russian (ru)**
7. For each addition, when prompted, make sure `Localizable.xcstrings` is checked

---

## 💻 How to Use in Code

### Basic Usage in SwiftUI

Replace hardcoded strings with localized versions:

**Before:**
```swift
Text("Welcome")
Button("Save") { }
```

**After:**
```swift
Text("welcome")
Button("save") { }
```

SwiftUI automatically looks up strings in the String Catalog!

### Using NSLocalizedString

For more complex cases or UIKit:

```swift
let message = NSLocalizedString("welcome", comment: "Welcome message")
```

### With String Interpolation

```swift
// In Localizable.xcstrings, add:
// "invoice_number" : "Invoice #%@"

Text("invoice_number")
    .localizedStringKey(String(format: NSLocalizedString("invoice_number", comment: ""), invoiceNum))
```

Or use String format directly:

```swift
String(format: NSLocalizedString("invoice_number", comment: "Invoice number"), invoiceNum)
```

### Pluralization (Important for Russian!)

Russian has complex plural rules. String Catalogs handle this automatically:

**In Localizable.xcstrings:**
```json
"items_count" : {
  "localizations" : {
    "en" : {
      "variations" : {
        "plural" : {
          "one" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "%lld item"
            }
          },
          "other" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "%lld items"
            }
          }
        }
      }
    },
    "ru" : {
      "variations" : {
        "plural" : {
          "one" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "%lld элемент"
            }
          },
          "few" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "%lld элемента"
            }
          },
          "many" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "%lld элементов"
            }
          },
          "other" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "%lld элемента"
            }
          }
        }
      }
    }
  }
}
```

**In Code:**
```swift
Text("items_count", comment: "Number of items")
```

---

## ✏️ Adding New Translations

### Method 1: Edit in Xcode (Recommended)

1. Open `Localizable.xcstrings` in Xcode
2. You'll see a nice table with all languages
3. Click the **+** button at the bottom
4. Enter the key name (e.g., "new_feature")
5. Add translations for English, Spanish, Russian
6. Add a comment explaining where it's used

### Method 2: Edit JSON Manually

Add to `Localizable.xcstrings`:

```json
"your_new_key" : {
  "comment" : "Description of where this is used",
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "English text"
      }
    },
    "es" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Texto en español"
      }
    },
    "ru" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Текст на русском"
      }
    }
  }
}
```

---

## 🧪 Testing Different Languages

### On Simulator/Device:

1. Go to Settings → General → Language & Region
2. Change "iPhone Language" to Spanish or Russian
3. Your app will restart and use that language

### In Xcode (Scheme Editor):

1. Edit your scheme (Product → Scheme → Edit Scheme)
2. Go to "Run" → "Options"
3. Set "App Language" to Spanish or Russian
4. Run the app - it will launch in that language

### Quick Test in Code (Not for Production):

```swift
// In your preview or debug code only
.environment(\.locale, Locale(identifier: "es")) // Spanish
.environment(\.locale, Locale(identifier: "ru")) // Russian
```

---

## 🎨 String Catalog Features

### Substitutions
Use `%@` for strings, `%lld` for integers, `%f` for floats:

```json
"welcome_user" : {
  "localizations" : {
    "en" : { "stringUnit" : { "state" : "translated", "value" : "Welcome, %@!" } },
    "es" : { "stringUnit" : { "state" : "translated", "value" : "¡Bienvenido, %@!" } },
    "ru" : { "stringUnit" : { "state" : "translated", "value" : "Добро пожаловать, %@!" } }
  }
}
```

In code:
```swift
String(format: NSLocalizedString("welcome_user", comment: ""), userName)
```

### Device Variants
Different text for iPhone vs iPad:

```json
"device_variant" : {
  "localizations" : {
    "en" : {
      "variations" : {
        "device" : {
          "iphone" : { "stringUnit" : { "state" : "translated", "value" : "Tap here" } },
          "ipad" : { "stringUnit" : { "state" : "translated", "value" : "Click here" } }
        }
      }
    }
  }
}
```

---

## 📋 Common Invoice App Strings

Here are key strings you'll want to add:

### Core Features
- `"client"` - Client/Cliente/Клиент
- `"invoice_number"` - Invoice Number/Número de factura/Номер счёта
- `"date"` - Date/Fecha/Дата
- `"due_date"` - Due Date/Fecha de vencimiento/Срок оплаты
- `"amount"` - Amount/Cantidad/Сумма
- `"total"` - Total/Total/Итого
- `"subtotal"` - Subtotal/Subtotal/Промежуточный итог
- `"tax"` - Tax/Impuesto/Налог
- `"paid"` - Paid/Pagado/Оплачено
- `"unpaid"` - Unpaid/No pagado/Не оплачено

### Actions
- `"create_invoice"` - Create Invoice/Crear factura/Создать счёт
- `"edit_invoice"` - Edit Invoice/Editar factura/Редактировать счёт
- `"send_invoice"` - Send Invoice/Enviar factura/Отправить счёт
- `"export"` - Export/Exportar/Экспорт
- `"share"` - Share/Compartir/Поделиться

### Settings
- `"settings"` - Settings/Configuración/Настройки
- `"account"` - Account/Cuenta/Аккаунт
- `"subscription"` - Subscription/Suscripción/Подписка
- `"logout"` - Log Out/Cerrar sesión/Выйти

---

## 🔍 Finding Hardcoded Strings

To find strings that need localization:

```bash
# Search for Text("...") with hardcoded strings
grep -r 'Text("' Invoice/ --include="*.swift"

# Search for Button("...") with hardcoded strings
grep -r 'Button("' Invoice/ --include="*.swift"
```

---

## 🌐 Translation Tips

### Spanish
- Use neutral Spanish (not specific to Spain/Mexico/Argentina)
- Pay attention to formal (usted) vs informal (tú) - use formal for business app
- Longer than English by ~15-25%

### Russian
- Cyrillic characters: ensure fonts support them
- Very complex plural forms (0, 1, 2-4, 5-20, etc.)
- Formal tone for business context
- Often 10-15% longer than English

---

## 🚨 Common Mistakes to Avoid

1. ❌ **Don't concatenate strings**
   ```swift
   // BAD
   Text("Invoice") + Text(" #\(number)")
   
   // GOOD - use format string
   Text("invoice_number")
   ```

2. ❌ **Don't hardcode plurals**
   ```swift
   // BAD
   Text("\(count) item\(count == 1 ? "" : "s")")
   
   // GOOD - use plural variations in String Catalog
   ```

3. ❌ **Don't forget comments**
   - Always add context to help translators

4. ❌ **Don't assume text length**
   - Use flexible layouts that handle longer text

---

## 📊 Your Current Setup

- ✅ String Catalog created at `Invoice/Localizable.xcstrings`
- ✅ Base language: English
- ✅ Spanish (es) configured
- ✅ Russian (ru) configured
- ⚠️ **TODO**: Add Localizable.xcstrings to Xcode project
- ⚠️ **TODO**: Configure project localizations in Xcode
- ⚠️ **TODO**: Start replacing hardcoded strings

---

## 🔗 Resources

- [Apple String Catalogs Documentation](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [Localization in SwiftUI](https://developer.apple.com/documentation/swiftui/localizing-your-app)
- [Russian Plural Rules](https://www.unicode.org/cldr/charts/43/supplemental/language_plural_rules.html#ru)

---

## 🎯 Next Steps

1. **Add the file to Xcode** (see instructions above)
2. **Configure localizations** in project settings
3. **Test with different languages** using Xcode scheme
4. **Start migrating strings** from ContentView.swift
5. **Get professional translation review** (especially for Russian plurals)

---

Need help? Check the Xcode String Catalog editor by opening `Localizable.xcstrings` in Xcode!
