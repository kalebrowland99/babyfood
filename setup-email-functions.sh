#!/bin/bash

# Firebase Cloud Functions Setup Script for Email Verification
# Run this script in your project root directory

echo "🚀 Setting up Firebase Cloud Functions for Email Verification..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
fi

# Login to Firebase
echo "🔐 Logging into Firebase..."
firebase login

# Initialize functions
echo "📦 Initializing Firebase Functions..."
firebase init functions --project default

# Navigate to functions directory
cd functions

# Install dependencies
echo "📚 Installing dependencies..."
npm install nodemailer @types/nodemailer @sendgrid/mail

# Create the TypeScript function
echo "📝 Creating email verification function..."
cat > src/index.ts << 'EOL'
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
      html: \`
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
              <div class="code">\${verificationCode}</div>
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
      \`,
      text: \`
Your Verification Code

Hello!

You requested a verification code for your account. Enter the code below to continue:

\${verificationCode}

This code will expire in 10 minutes.

If you didn't request this code, you can safely ignore this email.

Best regards,
The App Team
      \`.trim(),
    };
    
    // Send email
    await transporter.sendMail(mailOptions);
    
    console.log(\`✅ Verification email sent successfully to \${email}\`);
    return { success: true, message: 'Verification email sent successfully' };
    
  } catch (error) {
    console.error('❌ Error sending verification email:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send verification email'
    );
  }
});
EOL

# Build the function
echo "🔨 Building function..."
npm run build

echo ""
echo "✅ Firebase Functions setup complete!"
echo ""
echo "📧 Next steps:"
echo "1. Set up email credentials:"
echo "   For Gmail: firebase functions:config:set gmail.email=\"your-email@gmail.com\" gmail.password=\"your-app-password\""
echo "   For SendGrid: firebase functions:config:set sendgrid.api_key=\"your-sendgrid-api-key\""
echo ""
echo "2. Deploy the function:"
echo "   firebase deploy --only functions"
echo ""
echo "3. Test the function in your iOS app!"
echo ""
echo "📖 For detailed instructions, see firebase-functions-setup.md" 