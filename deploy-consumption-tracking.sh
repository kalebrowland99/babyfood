#!/bin/bash

# Apple Consumption Tracking Deployment Script
# This script helps deploy Firebase Functions and configure Apple consumption tracking

set -e  # Exit on any error

echo "🍎 Apple Consumption Tracking Deployment Script"
echo "================================================"

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
fi

# Check if logged in to Firebase
echo "🔐 Checking Firebase authentication..."
if ! firebase projects:list &> /dev/null; then
    echo "🔑 Please login to Firebase:"
    firebase login
fi

# Navigate to functions directory
cd functions

echo "📦 Installing dependencies..."
npm install

echo "🚀 Deploying Firebase Functions..."
firebase deploy --only functions

echo "✅ Firebase Functions deployed successfully!"
echo ""
echo "🔧 Next Steps Required:"
echo "======================"
echo ""
echo "1. Configure Firebase Secrets:"
echo "   firebase functions:secrets:set APPLE_KEY_ID=\"YOUR_APPLE_KEY_ID\""
echo "   firebase functions:secrets:set APPLE_ISSUER_ID=\"YOUR_APPLE_ISSUER_ID\""
echo "   firebase functions:secrets:set APPLE_PRIVATE_KEY=\"YOUR_BASE64_ENCODED_PRIVATE_KEY\""
echo "   firebase functions:secrets:set REVENUECAT_API_KEY=\"YOUR_REVENUECAT_API_KEY\""
echo ""
echo "2. Set Apple Environment:"
echo "   firebase functions:config:set apple.environment=\"SANDBOX\"  # or PRODUCTION"
echo ""
echo "3. Update App Store ID in functions/appleWebhook.js line 17"
echo ""
echo "4. Configure webhook in App Store Connect with this URL:"
firebase functions:list | grep appleConsumptionWebhook | head -1 || echo "   (Run 'firebase functions:list' to get the webhook URL)"
echo ""
echo "📖 See APPLE_CONSUMPTION_TRACKING_SETUP.md for detailed instructions"
