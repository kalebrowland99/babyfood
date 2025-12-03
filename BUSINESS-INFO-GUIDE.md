# 📄 Business Information Storage - Complete Guide

## ✅ What Was Implemented

Your invoice app now stores **business information directly in each invoice document**. This is the professional approach used by real invoice systems like QuickBooks, FreshBooks, and Wave.

---

## 🎯 How It Works

### **1. Business Settings Screen**
- Accessible from: **Settings → Business information**
- Configure your business details once
- Info is stored locally and reused for all new invoices

### **2. Invoice Document**
- Each invoice saves a **snapshot** of your business info
- Historical accuracy: Old invoices won't change if you update your business
- PDF and emails automatically use the invoice's business info

### **3. Email Sending**
- Sender name: `invoice.businessName`
- Sender email: `invoice.businessEmail` (or defaults to `invoices@resend.dev`)
- All dynamic - no more hardcoded "615films"!

---

## 📱 How to Use

### **Step 1: Set Up Your Business Information**

1. Open the app
2. Tap **Settings** (gear icon in top right)
3. Tap **Business information**
4. Fill in your details:
   - **Business Name** (Required) - e.g., "615films"
   - **Email** (Optional) - e.g., "invoices@615films.com"
   - **Phone** (Optional) - e.g., "(615) 555-1234"
   - **Address** (Optional) - e.g., "123 Main St, Nashville, TN 37201"
5. Tap **Save**

### **Step 2: Create an Invoice**

When you create a new invoice, your business info is **automatically** included:
- Pulled from saved settings
- Stored with the invoice
- Can't be changed after creation (maintains accuracy)

### **Step 3: Send the Invoice**

When you send the invoice via email:
- **From Name:** Your business name (e.g., "615films")
- **From Email:** Your business email or `invoices@resend.dev` if not set
- **PDF:** Shows your full business info in the "FROM" section
- **Email:** Signs with your business name

---

## 📧 Email Address Options

### **Option 1: Use `invoices@resend.dev` (Default)**
- **Setup:** None required (already working)
- **From Email:** `615films <invoices@resend.dev>`
- **Cost:** $0
- **Professionalism:** Good for testing/small business

### **Option 2: Use Your Custom Domain**
1. Add your domain to Resend (see `RESEND-SETUP-GUIDE.md`)
2. Update business email in settings: `invoices@yourdomain.com`
3. Rebuild the app
4. **From Email:** `615films <invoices@yourdomain.com>`
5. **Cost:** ~$12/year for domain
6. **Professionalism:** Best for established business

---

## 🔄 Data Flow

```
┌─────────────────────────────────────────────────┐
│  1. Business Settings Screen                     │
│     └─ User enters business info                │
│     └─ Saved to UserDefaults                    │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  2. Create Invoice                               │
│     └─ Loads business info from UserDefaults    │
│     └─ Stores in invoice.businessName, etc.     │
│     └─ Saves to Firestore                       │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  3. Send Invoice                                 │
│     └─ Uses invoice.businessName                │
│     └─ Uses invoice.businessEmail               │
│     └─ Sends to Firebase Cloud Function         │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│  4. Cloud Function                               │
│     └─ Generates PDF with business info         │
│     └─ Sends email with business name/email     │
│     └─ Customer receives professional invoice   │
└─────────────────────────────────────────────────┘
```

---

## 📋 What's Stored in Each Invoice

### **Business Fields (New):**
```swift
businessName: String         // "615films"
businessEmail: String?       // "invoices@615films.com"
businessPhone: String?       // "(615) 555-1234"
businessAddress: String?     // "123 Main St..."
```

### **Client Fields (Existing):**
```swift
client.name: String
client.email: String?
client.phone: String?
client.address: String?
```

### **Invoice Details (Existing):**
```swift
number: String
issuedDate: Date
items: [InvoiceItem]
total: Double
notes: String
// ... etc
```

---

## 📄 What Appears in PDFs

### **FROM Section (Top Left):**
```
FROM
615films                    ← businessName
invoices@615films.com      ← businessEmail (if set)
(615) 555-1234             ← businessPhone (if set)
123 Main St...             ← businessAddress (if set)
```

### **BILL TO Section (Top Right):**
```
BILL TO
Client Name                ← client.name
client@email.com          ← client.email (if set)
(555) 123-4567            ← client.phone (if set)
456 Oak Ave...            ← client.address (if set)
```

---

## 📧 What Appears in Emails

### **Email Header:**
```
From: 615films <invoices@615films.com>
To: client@email.com
Subject: Invoice #005 from 615films
```

### **Email Body:**
```
📄 615films                ← businessName in header

Hi Client Name,            ← client.name

Please find attached your latest invoice...

Invoice Details
#005                       ← invoice.number
$200.00                    ← invoice.total
Issued Nov 8, 2025         ← invoice.issuedDate

Many thanks,
615films                   ← businessName in signature
```

---

## 🔧 Technical Details

### **Files Modified:**
1. **`Invoice/CreateInvoiceFlow.swift`**
   - Added business fields to `Invoice` struct (lines 28-32)
   - Auto-loads from UserDefaults on init (lines 147-150)

2. **`Invoice/InvoiceSendFlow.swift`**
   - Uses `invoice.businessName` instead of hardcoded value (line 460)
   - Uses `invoice.businessEmail` for sender email (line 461)

3. **`Invoice/BusinessSettingsView.swift`** (NEW FILE)
   - Settings screen for business info
   - Saves to UserDefaults
   - Beautiful UI with icons

4. **`Invoice/ProfileSettingsView.swift`**
   - Connected to BusinessSettingsView (line 347)

### **Backend (No Changes Needed):**
The Firebase function already accepts `businessName` and `senderEmail` as parameters, so it works automatically!

---

## 🎨 Customization

### **Change Default Business Name:**
Edit `Invoice/CreateInvoiceFlow.swift` line 147:
```swift
businessName: UserDefaults.standard.string(forKey: "businessName") ?? "Your Company Name",
```

### **Change Email Fallback:**
Edit `Invoice/InvoiceSendFlow.swift` line 461:
```swift
"senderEmail": "\(invoice.businessName) <\(invoice.businessEmail ?? "invoices@yourdomain.com")>"
```

---

## ✨ Benefits of This Approach

### ✅ **Historical Accuracy**
- Old invoices keep original business info
- Won't break if you change your address/phone

### ✅ **No Hardcoding**
- All dynamic from settings
- Easy to update
- Professional approach

### ✅ **Self-Contained**
- Each invoice has everything it needs
- Can regenerate PDFs years later
- Audit-friendly

### ✅ **User-Friendly**
- Set once, use everywhere
- Beautiful settings screen
- Clear instructions

---

## 🚀 Quick Start

1. **Now:** Open app → Settings → Business information → Fill in details
2. **Then:** Create an invoice → Business info auto-fills
3. **Test:** Send invoice to yourself → Check email!

---

## 📊 Example Invoice Data in Firestore

```json
{
  "id": "abc123",
  "number": "005",
  "issuedDate": "2025-11-08T00:00:00Z",
  "businessName": "615films",
  "businessEmail": "invoices@615films.com",
  "businessPhone": "(615) 555-1234",
  "businessAddress": "123 Main St, Nashville, TN 37201",
  "client": {
    "name": "Chine Harris",
    "email": "chine@example.com"
  },
  "items": [...],
  "total": 200.00,
  "notes": "..."
}
```

---

## 🆘 Troubleshooting

### **Invoice shows "615films" even after I changed settings**
- Settings only apply to **new** invoices
- Old invoices keep their original business info (by design)
- Solution: Create a new invoice

### **Email sender still shows "invoices@resend.dev"**
- Check if you set Business Email in settings
- If blank, it defaults to `invoices@resend.dev`
- Solution: Settings → Business information → Add email

### **Business info not showing in PDF**
- Check if invoice was created after adding business info
- Check Firestore to see if invoice has business fields
- Solution: Create a fresh invoice

---

## 🎉 You're Done!

Your invoice system now works like a professional invoicing platform:
- ✅ Customizable business information
- ✅ Stored with each invoice
- ✅ Appears in PDFs and emails
- ✅ No hardcoded values
- ✅ Easy to manage

**Test it now:**
1. Go to Settings → Business information
2. Enter your business details
3. Create and send an invoice
4. Check your email! 📧

---

**Questions?** All the code is in place and working. Just add your business info in settings! 🚀

