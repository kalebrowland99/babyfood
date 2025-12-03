#!/bin/bash

# Firebase Email Verification Setup Script
# This script helps you set up email verification with Firebase

echo "🔥 Setting up Firebase Email Verification..."
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
fi

# Check if logged in
if ! firebase projects:list &> /dev/null; then
    echo "🔐 Please log in to Firebase..."
    firebase login
fi

echo "✅ Firebase CLI ready"
echo ""

# Show current project
echo "📋 Current Firebase project:"
firebase projects:list | grep "(current)"
echo ""

# Check if functions are deployed
echo "🔍 Checking deployed functions..."
firebase functions:list
echo ""

# Email provider selection
echo "📧 Choose your email provider:"
echo "1. Gmail (Recommended for testing)"
echo "2. SendGrid (Recommended for production)"
echo "3. Skip email setup (use development mode)"
echo ""

read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        echo ""
        echo "📧 Setting up Gmail..."
        echo ""
        echo "To set up Gmail:"
        echo "1. Create a Gmail account for your app (e.g., app.noreply@gmail.com)"
        echo "2. Enable 2-factor authentication"
        echo "3. Generate an App Password:"
        echo "   - Go to Google Account settings"
        echo "   - Security → 2-Step Verification → App passwords"
        echo "   - Generate password for 'Mail'"
        echo ""
        read -p "Enter your Gmail address: " gmail_email
        read -s -p "Enter your Gmail App Password: " gmail_password
        echo ""
        
        # Set environment variables
        echo "🔧 Setting up environment variables..."
        firebase functions:secrets:set GMAIL_EMAIL "$gmail_email"
        firebase functions:secrets:set GMAIL_PASSWORD "$gmail_password"
        
        echo "✅ Gmail configured!"
        ;;
    2)
        echo ""
        echo "📧 Setting up SendGrid..."
        echo ""
        echo "To set up SendGrid:"
        echo "1. Sign up for SendGrid (free tier: 100 emails/day)"
        echo "2. Verify your domain"
        echo "3. Create API key"
        echo ""
        read -s -p "Enter your SendGrid API key: " sendgrid_key
        echo ""
        
        # Set environment variables
        echo "🔧 Setting up environment variables..."
        firebase functions:secrets:set SENDGRID_API_KEY "$sendgrid_key"
        
        # Update function to use SendGrid
        echo "📝 Updating function to use SendGrid..."
        cp functions/index-sendgrid.js functions/index.js
        
        echo "✅ SendGrid configured!"
        ;;
    3)
        echo ""
        echo "⚠️  Skipping email setup. You can use development mode:"
        echo "   - Use 'apple@test.com' with code '1234' for testing"
        echo "   - Check console logs for verification codes"
        echo ""
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

# Deploy functions
if [ "$choice" != "3" ]; then
    echo ""
    echo "🚀 Deploying updated functions..."
    cd functions
    npm install
    firebase deploy --only functions
    cd ..
    echo "✅ Functions deployed!"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📱 Next steps:"
echo "1. Run your iOS app"
echo "2. Test email sign-in with a real email address"
echo "3. Check Firebase Functions logs: firebase functions:log"
echo ""
echo "🔧 For development testing:"
echo "   - Use 'apple@test.com' with code '1234'"
echo "   - Check console for verification codes if email fails"
echo ""
echo "📖 Full setup guide: Firebase-Setup-Complete.md" 