# Resend Invoice Email Setup Guide

Complete setup guide for sending invoices via email using Resend.

## 📋 What You Need

- ✅ Resend account (free tier: 3,000 emails/month)
- ✅ Custom domain (optional but recommended)
- ✅ Firebase project with Cloud Functions enabled
- ✅ Node.js 22 installed

---

## 🚀 Step 1: Create Resend Account

1. **Go to [resend.com](https://resend.com)**

2. **Sign up for free**
   - Click "Sign up"
   - Use your GitHub or email
   - Verify your email

3. **Get your API key**
   - Go to **API Keys** in the dashboard
   - Click "Create API Key"
   - Name it: "Invoice App"
   - **Copy the API key** (starts with `re_...`)
   - ⚠️ **Save it somewhere safe - you won't see it again!**

---

## 🌐 Step 2: Domain Setup (Optional but Recommended)

### Option A: Use Resend's Test Domain (Quick Start)
For testing, you can use `invoices@resend.dev` - no setup required!

### Option B: Add Your Custom Domain (Professional)

1. **In Resend Dashboard:**
   - Go to **Domains**
   - Click "Add Domain"
   - Enter your domain (e.g., `yourbusiness.com`)

2. **Add DNS Records:**
   Copy these 3 DNS records to your domain provider (Namecheap, GoDaddy, Cloudflare, etc.):
   
   ```
   SPF Record (TXT):
   Name: @
   Value: v=spf1 include:amazonses.com ~all
   
   DKIM Record (TXT):
   Name: resend._domainkey
   Value: [Resend will provide this]
   
   DMARC Record (TXT):
   Name: _dmarc
   Value: v=DMARC1; p=none; rua=mailto:dmarc@yourdomain.com
   ```

3. **Wait for Verification** (1-48 hours)
   - Resend will verify your DNS records
   - You'll get an email when it's ready

4. **Update the sender email:**
   In the code: Change `invoices@resend.dev` to `invoices@yourdomain.com`

---

## 🔥 Step 3: Install Dependencies

```bash
cd functions
npm install
```

This will install:
- ✅ `resend` - Email sending
- ✅ `pdfkit` - PDF generation
- ✅ Firebase Admin SDK (already installed)

---

## 🔐 Step 4: Configure Firebase Environment Variables

You need to add your Resend API key to Firebase:

### Option A: Using Firebase CLI (Recommended)

```bash
# Navigate to your project root
cd /Users/elianasilva/Desktop/invoice

# Set the Resend API key
firebase functions:secrets:set RESEND_API_KEY

# When prompted, paste your API key from Step 1
```

### Option B: Using .env File (Local Testing Only)

Create `functions/.env`:

```bash
RESEND_API_KEY=re_your_api_key_here
```

⚠️ **Never commit `.env` to git!** (It's already in `.gitignore`)

---

## 🚀 Step 5: Deploy Firebase Functions

```bash
# From project root
firebase deploy --only functions
```

This will deploy the `sendInvoice` cloud function.

**Expected output:**
```
✔  functions[sendInvoice] Successful create operation.
Function URL: https://us-central1-your-project.cloudfunctions.net/sendInvoice
```

---

## 📱 Step 6: Update iOS App Configuration

The iOS code is already updated! Just make sure you have:

1. **Firebase configured** in your Xcode project
2. **FirebaseFunctions** package imported
3. The app can connect to Firebase

---

## ✅ Step 7: Test the Integration

### Test Invoice Sending:

1. **Create an invoice** in the app
2. **Add a client** with an email address
3. **Tap "Send Invoice"**
4. **Enter the recipient email** (use your own email for testing)
5. **Tap "Send"**
6. **Check your email!** 📧

### What to Expect:

- ✅ Loading spinner appears
- ✅ Confetti animation plays
- ✅ Sheet dismisses
- ✅ Email arrives with PDF attachment within seconds
- ✅ Invoice status updates to "sent" in Firestore

### Troubleshooting:

If the email doesn't send:

1. **Check Firebase Functions logs:**
   ```bash
   firebase functions:log
   ```

2. **Check Resend Dashboard:**
   - Go to **Logs** tab
   - Look for failed sends
   - Check for errors

3. **Common Issues:**
   - ❌ API key not set correctly
   - ❌ Domain not verified (if using custom domain)
   - ❌ Invalid email address
   - ❌ Firebase Functions not deployed

---

## 💰 Pricing & Limits

### Resend Free Tier:
- ✅ **3,000 emails/month**
- ✅ **100 emails/day**
- ✅ 1 custom domain
- ✅ Email API access

### When to Upgrade:
- **Pro ($20/month)**: 50,000 emails/month
- **Scale ($85/month)**: 500,000 emails/month

### Firebase Functions Cost:
- **Free tier**: 2 million invocations/month
- **After that**: $0.40 per million invocations
- **Extremely cheap** for most use cases

---

## 📊 Monitoring & Analytics

### Resend Dashboard:
Track all sent emails:
- View delivery status
- See open rates (if enabled)
- Check bounces and spam reports
- Download logs

### Firebase Console:
Track function executions:
- Go to **Functions** tab
- View execution times
- Check error rates
- Monitor costs

---

## 🎨 Customization

### Change Email Template:

Edit `functions/invoiceService.js` → `generateInvoiceEmailHTML()` function:

```javascript
// Customize colors, fonts, layout, etc.
const emailHTML = `
  <html>
    <style>
      /* Your custom styles */
    </style>
    <body>
      <!-- Your custom template -->
    </body>
  </html>
`;
```

### Change PDF Layout:

Edit `functions/invoiceService.js` → `generateInvoicePDF()` function:

```javascript
// Customize PDF layout, fonts, colors
doc.fontSize(28).text('INVOICE', 50, 50);
```

### Change Sender Name/Email:

In `Invoice/InvoiceSendFlow.swift`:

```swift
"businessName": "Your Business Name",
"senderEmail": "Your Name <invoices@yourdomain.com>"
```

---

## 🔒 Security Best Practices

1. ✅ **Never expose API keys** in client code
2. ✅ **Validate email addresses** on both client and server
3. ✅ **Store PDFs in Firebase Storage** (already implemented)
4. ✅ **Track sent invoices** in Firestore (already implemented)
5. ✅ **Use environment variables** for sensitive data

---

## 🆘 Support & Resources

### Resend:
- 📚 [Documentation](https://resend.com/docs)
- 💬 [Discord Community](https://discord.gg/resend)
- 📧 [Support Email](mailto:support@resend.com)

### Firebase:
- 📚 [Functions Documentation](https://firebase.google.com/docs/functions)
- 💬 [Stack Overflow](https://stackoverflow.com/questions/tagged/firebase-functions)

### PDFKit:
- 📚 [Documentation](http://pdfkit.org/)
- 💻 [GitHub](https://github.com/foliojs/pdfkit)

---

## 🎉 You're Done!

Your invoice app is now configured to send professional emails with PDF attachments!

**Next Steps:**
1. Test with a real invoice
2. Customize the email template
3. Add your custom domain
4. Start sending invoices! 📧

---

## 📝 Quick Reference

### Environment Variables:
```bash
RESEND_API_KEY=re_xxxxx  # Required
```

### Firebase Functions:
```bash
# Deploy
firebase deploy --only functions

# View logs
firebase functions:log

# Test locally
firebase emulators:start --only functions
```

### File Locations:
- Cloud Function: `functions/index.js` (line 975+)
- Email Service: `functions/invoiceService.js`
- iOS Code: `Invoice/InvoiceSendFlow.swift`
- Package Config: `functions/package.json`

---

**Questions?** Feel free to ask! 🚀

