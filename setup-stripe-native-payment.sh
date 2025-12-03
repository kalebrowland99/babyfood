#!/bin/bash

# Stripe Native Payment Setup Script
# This script helps configure Firestore for native Stripe payments

echo "🎯 Stripe Native Payment Setup"
echo "================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI not found${NC}"
    echo "Install with: npm install -g firebase-tools"
    exit 1
fi

echo -e "${GREEN}✅ Firebase CLI found${NC}"
echo ""

# Check if logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged in to Firebase${NC}"
    echo "Logging in..."
    firebase login
fi

echo -e "${GREEN}✅ Logged in to Firebase${NC}"
echo ""

# Step 1: Set up Firebase secrets
echo -e "${BLUE}Step 1: Setting up Firebase Secrets${NC}"
echo "-----------------------------------"
echo ""
echo "You'll need to provide your Stripe API keys."
echo "Find them at: https://dashboard.stripe.com/apikeys"
echo ""

read -p "Do you want to set up Stripe secrets now? (y/n): " setup_secrets

if [[ $setup_secrets == "y" || $setup_secrets == "Y" ]]; then
    echo ""
    echo "Setting up TEST mode secrets..."
    firebase functions:secrets:set STRIPE_SECRET_KEY_TEST
    firebase functions:secrets:set STRIPE_WEBHOOK_SECRET_TEST
    
    echo ""
    echo "Setting up PRODUCTION mode secrets..."
    firebase functions:secrets:set STRIPE_SECRET_KEY_PROD
    firebase functions:secrets:set STRIPE_WEBHOOK_SECRET_PROD
    
    echo -e "${GREEN}✅ Secrets configured${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping secret setup${NC}"
fi

echo ""

# Step 2: Deploy Firebase Functions
echo -e "${BLUE}Step 2: Deploying Firebase Functions${NC}"
echo "------------------------------------"
echo ""

read -p "Do you want to deploy Firebase functions now? (y/n): " deploy_functions

if [[ $deploy_functions == "y" || $deploy_functions == "Y" ]]; then
    cd functions
    echo "Installing dependencies..."
    npm install
    echo "Deploying functions..."
    firebase deploy --only functions
    cd ..
    echo -e "${GREEN}✅ Functions deployed${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping function deployment${NC}"
    echo "You'll need to run: cd functions && firebase deploy --only functions"
fi

echo ""

# Step 3: Firestore Configuration
echo -e "${BLUE}Step 3: Firestore Configuration${NC}"
echo "-------------------------------"
echo ""
echo "Creating Firestore configuration document..."
echo "Collection: app_config"
echo "Document: paywall_config"
echo ""

read -p "Start with TEST mode? (recommended) (y/n): " use_test_mode

if [[ $use_test_mode == "y" || $use_test_mode == "Y" ]]; then
    production_mode="false"
    mode_label="TEST"
else
    production_mode="true"
    mode_label="PRODUCTION"
fi

read -p "Enable native in-app payment sheet? (recommended) (y/n): " use_native_sheet

if [[ $use_native_sheet == "y" || $use_native_sheet == "Y" ]]; then
    stripe_sheet="true"
    sheet_label="Native In-App"
else
    stripe_sheet="false"
    sheet_label="External Browser"
fi

echo ""
echo "Configuration Summary:"
echo "----------------------"
echo -e "Mode: ${YELLOW}${mode_label}${NC}"
echo -e "Payment Type: ${YELLOW}${sheet_label}${NC}"
echo ""

# Create Firestore config JSON
cat > /tmp/firestore-config.json << EOF
{
  "hardpaywall": true,
  "stripepaywall": true,
  "usestripesheet": ${stripe_sheet},
  "useproductionmode": ${production_mode},
  "stripecheckouturl": "https://us-central1-thrift-882cb.cloudfunctions.net/getStripeCheckoutUrl",
  "stripecheckouturltest": "https://us-central1-thrift-882cb.cloudfunctions.net/getStripeCheckoutUrl",
  "winbackcheckouturl": "https://us-central1-thrift-882cb.cloudfunctions.net/getStripeCheckoutUrl?isWinback=true",
  "winbackcheckouturltest": "https://us-central1-thrift-882cb.cloudfunctions.net/getStripeCheckoutUrl?isWinback=true",
  "stripebuttontext": "Try for $0.00",
  "stripedisclaimertext": "Free for 3 days, then $79.99 per year after.",
  "winbackdisclaimertext": "Free for 3 days, then $79.00 per year after.",
  "termsurl": "https://thrifty.com/terms"
}
EOF

echo "Configuration file created at: /tmp/firestore-config.json"
echo ""
echo "⚠️  You'll need to manually add this to Firestore:"
echo "1. Go to Firebase Console → Firestore Database"
echo "2. Navigate to: app_config/paywall_config"
echo "3. Copy the contents from: /tmp/firestore-config.json"
echo "4. Paste into Firestore document"
echo ""

# Display the configuration
echo -e "${BLUE}Configuration to add:${NC}"
cat /tmp/firestore-config.json
echo ""

# Step 4: Deploy Firestore Rules
echo -e "${BLUE}Step 4: Deploying Firestore Rules${NC}"
echo "---------------------------------"
echo ""

read -p "Do you want to deploy Firestore rules now? (y/n): " deploy_rules

if [[ $deploy_rules == "y" || $deploy_rules == "Y" ]]; then
    firebase deploy --only firestore:rules
    echo -e "${GREEN}✅ Firestore rules deployed${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping rules deployment${NC}"
    echo "You'll need to run: firebase deploy --only firestore:rules"
fi

echo ""

# Final Summary
echo ""
echo "================================"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo "================================"
echo ""
echo "Next Steps:"
echo "1. Add the configuration to Firestore (app_config/paywall_config)"
echo "2. Open Xcode and build your app"
echo "3. Test with Stripe test cards:"
echo "   - Success: 4242 4242 4242 4242"
echo "   - Decline: 4000 0000 0000 0002"
echo ""
echo "Testing Flow:"
echo "1. Log in to your app"
echo "2. Navigate to paywall"
echo "3. Tap subscription button"
echo "4. Native payment sheet should appear (if enabled)"
echo "5. Enter test card details"
echo "6. Verify subscription activates"
echo ""
echo "For full documentation, see: STRIPE_NATIVE_PAYMENT_SETUP.md"
echo ""

