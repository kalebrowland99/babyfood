# Firebase Cloud Functions Setup for Email Verification

This guide shows you how to set up Firebase Cloud Functions to send real verification emails for your app.

## 1. Prerequisites

1. **Firebase CLI**: Install if you haven't already
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**:
   ```bash
   firebase login
   ```

## 2. Initialize Firebase Functions

In your project root directory:

```bash
# Initialize functions in your existing Firebase project
firebase init functions

# Choose:
# - Use existing project (select your project)
# - JavaScript or TypeScript (recommend TypeScript)
# - Install dependencies: Yes
```

## 3. Install Email Service Dependencies

Navigate to your `functions` folder and install email service:

```bash
cd functions
npm install nodemailer @types/nodemailer
# OR for SendGrid:
# npm install @sendgrid/mail
```

## 4. Add Environment Variables

Set up your email service credentials:

```bash
# For Gmail (easier for testing):
firebase functions:config:set gmail.email="your-gmail@gmail.com" gmail.password="your-app-password"

# OR for SendGrid (recommended for production):
firebase functions:config:set sendgrid.api_key="your-sendgrid-api-key"

# OR for custom SMTP:
firebase functions:config:set smtp.host="smtp.your-provider.com" smtp.port="587" smtp.user="your-email" smtp.pass="your-password"
```

## 5. Cloud Function Code

Replace the contents of `functions/src/index.ts` with:

```typescript
import * as functions from 'firebase-functions';
import * as nodemailer from 'nodemailer';

// Initialize email transporter
const createTransporter = () => {
  const config = functions.config();
  
  // Option 1: Gmail (easiest for testing)
  if (config.gmail) {
    return nodemailer.createTransporter({
      service: 'gmail',
      auth: {
        user: config.gmail.email,
        pass: config.gmail.password, // Use App Password, not regular password
      },
    });
  }
  
  // Option 2: Custom SMTP
  if (config.smtp) {
    return nodemailer.createTransporter({
      host: config.smtp.host,
      port: parseInt(config.smtp.port),
      secure: false,
      auth: {
        user: config.smtp.user,
        pass: config.smtp.pass,
      },
    });
  }
  
  throw new Error('No email configuration found');
};

// Email verification function
export const sendVerificationEmail = functions.https.onCall(async (data, context) => {
  const { email, verificationCode, appName } = data;
  
  // Validate input
  if (!email || !verificationCode || !appName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: email, verificationCode, or appName'
    );
  }
  
  // Email validation
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid email address'
    );
  }
  
  try {
    const transporter = createTransporter();
    
    // Email content
    const mailOptions = {
      from: '"App Team" <noreply@your-domain.com>', // Replace with your domain
      to: email,
      subject: 'Your Verification Code',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Email Verification</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { text-align: center; margin-bottom: 30px; }
            .logo { font-size: 24px; font-weight: bold; color: #000; }
            .code-box { background: #f8f9fa; border: 2px solid #e9ecef; border-radius: 8px; padding: 20px; text-align: center; margin: 20px 0; }
            .code { font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #000; }
            .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #e9ecef; font-size: 14px; color: #666; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <div class="logo">📄 App</div>
            </div>
            
            <h2>Email Verification</h2>
            <p>Hello!</p>
            <p>You requested a verification code for your account. Enter the code below to continue:</p>
            
            <div class="code-box">
              <div class="code">${verificationCode}</div>
            </div>
            
            <p><strong>This code will expire in 10 minutes.</strong></p>
            <p>If you didn't request this code, you can safely ignore this email.</p>
            
            <div class="footer">
              <p>Best regards,<br>The App Team</p>
              <p style="font-size: 12px; margin-top: 20px;">
                This is an automated message. Please do not reply to this email.
              </p>
            </div>
          </div>
        </body>
        </html>
      `,
      text: `
Your Verification Code

Hello!

You requested a verification code for your account. Enter the code below to continue:

${verificationCode}

This code will expire in 10 minutes.

If you didn't request this code, you can safely ignore this email.

Best regards,
The App Team
      `.trim(),
    };
    
    // Send email
    await transporter.sendMail(mailOptions);
    
    console.log(`✅ Verification email sent successfully to ${email}`);
    return { success: true, message: 'Verification email sent successfully' };
    
  } catch (error) {
    console.error('❌ Error sending verification email:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send verification email'
    );
  }
});

// Optional: SendGrid version (if you prefer SendGrid over SMTP)
/*
import sgMail from '@sendgrid/mail';

export const sendVerificationEmailSendGrid = functions.https.onCall(async (data, context) => {
  const { email, verificationCode, appName } = data;
  
  if (!email || !verificationCode || !appName) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }
  
  try {
    const config = functions.config();
    sgMail.setApiKey(config.sendgrid.api_key);
    
    const msg = {
      to: email,
      from: 'noreply@your-domain.com', // Replace with your verified sender
      subject: 'Your Verification Code',
      templateId: 'your-sendgrid-template-id', // Create template in SendGrid
      dynamicTemplateData: {
        verificationCode: verificationCode,
        appName: appName,
      },
    };
    
    await sgMail.send(msg);
    return { success: true, message: 'Verification email sent successfully' };
    
  } catch (error) {
    console.error('Error sending email:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send verification email');
  }
});
*/

## 6. Deploy the Function

```bash
firebase deploy --only functions
```

## 7. Gmail App Password Setup (if using Gmail)

1. Enable 2-factor authentication on your Gmail account
2. Go to Google Account settings > Security > 2-Step Verification > App passwords
3. Generate an app password for "Mail"
4. Use this app password (not your regular password) in the Firebase config

## 8. Production Recommendations

### For Production, Consider:

1. **Custom Domain**: Set up a custom domain for your from address
2. **SendGrid/Mailgun**: More reliable than Gmail for production
3. **Email Templates**: Create branded HTML templates
4. **Rate Limiting**: Add rate limiting to prevent abuse
5. **Analytics**: Track email open rates and deliverability

### Example Production SendGrid Setup:

```bash
# Set SendGrid API key
firebase functions:config:set sendgrid.api_key="SG.your-api-key"

# Use the SendGrid version in the code comments above
```

## 9. Testing

1. Deploy your functions
2. Test in your iOS app
3. Check Firebase Functions logs for any errors:
   ```bash
   firebase functions:log
   ```

## 10. Security Notes

- Never commit API keys to your repository
- Use Firebase environment variables for all secrets
- Consider adding rate limiting to prevent abuse
- Validate all inputs in your Cloud Function
- Use verified sender domains in production

## Troubleshooting

1. **"Functions not found"**: Make sure you deployed with `firebase deploy --only functions`
2. **Email not sending**: Check Firebase Functions logs for detailed error messages
3. **Gmail authentication**: Make sure you're using an App Password, not your regular Gmail password
4. **CORS errors**: This shouldn't be an issue with `httpsCallable` from Firebase SDK

Your iOS app will now send real emails through Firebase Cloud Functions! 🎉 