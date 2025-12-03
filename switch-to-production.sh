#!/bin/bash

# Switch Thrifty App to Production Keys
# This script helps you switch from test/sandbox to production/live keys

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Thrifty App - Switch to Production Keys"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Change to functions directory
cd "$(dirname "$0")/functions" || exit 1

echo "📍 Current directory: $(pwd)"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed. Please install it first:"
    echo "   npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI found"
echo ""

# Display current configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Current Configuration:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
firebase functions:config:get apple.environment 2>/dev/null || echo "Apple environment: Not set"
echo ""

# Confirm before proceeding
echo "⚠️  WARNING: This will switch your app to PRODUCTION mode!"
echo "   - Apple StoreKit: SANDBOX → PRODUCTION"
echo "   - Stripe: Test keys → Live keys"
echo ""
read -p "Are you ready to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Aborted. No changes made."
    exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1/4: Switch Apple Environment to PRODUCTION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -p "Set Apple environment to PRODUCTION? (yes/no): " apple_confirm

if [ "$apple_confirm" = "yes" ]; then
    echo "🔄 Setting Apple environment to PRODUCTION..."
    firebase functions:config:set apple.environment="PRODUCTION"
    
    if [ $? -eq 0 ]; then
        echo "✅ Apple environment set to PRODUCTION"
    else
        echo "❌ Failed to set Apple environment"
        exit 1
    fi
else
    echo "⏭️  Skipped Apple environment"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2/4: Configure Stripe Live Secret Key"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Instructions:"
echo "   1. Go to https://dashboard.stripe.com"
echo "   2. Switch to LIVE mode (toggle in top right)"
echo "   3. Go to Developers → API Keys"
echo "   4. Copy your Secret key (starts with sk_live_)"
echo ""

read -p "Do you have your Stripe LIVE secret key ready? (yes/no): " stripe_confirm

if [ "$stripe_confirm" = "yes" ]; then
    echo ""
    echo "🔄 Setting Stripe secret key..."
    echo "   You'll be prompted to enter the key. Paste: sk_live_XXXXXXXXX"
    echo ""
    firebase functions:secrets:set STRIPE_SECRET_KEY
    
    if [ $? -eq 0 ]; then
        echo "✅ Stripe secret key configured"
    else
        echo "❌ Failed to set Stripe secret key"
        exit 1
    fi
else
    echo "⏭️  Skipped Stripe key configuration"
    echo "⚠️  Remember to set it later with: firebase functions:secrets:set STRIPE_SECRET_KEY"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3/4: Update Firestore Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Manual step required:"
echo "   1. Go to Firebase Console → Firestore Database"
echo "   2. Navigate to: app_config/paywall_config"
echo "   3. Update field 'stripecheckouturl' with your LIVE Stripe checkout URL"
echo "   4. The URL should look like: https://buy.stripe.com/live_XXXXXXXXX"
echo ""

read -p "Press Enter when you've updated Firestore..."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4/4: Deploy Functions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -p "Deploy all functions with new configuration? (yes/no): " deploy_confirm

if [ "$deploy_confirm" = "yes" ]; then
    echo "🚀 Deploying functions..."
    firebase deploy --only functions
    
    if [ $? -eq 0 ]; then
        echo "✅ Functions deployed successfully"
    else
        echo "❌ Failed to deploy functions"
        exit 1
    fi
else
    echo "⏭️  Skipped deployment"
    echo "⚠️  Remember to deploy later with: firebase deploy --only functions"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Production Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary of changes:"
echo "   ✅ Apple environment: PRODUCTION"
if [ "$stripe_confirm" = "yes" ]; then
    echo "   ✅ Stripe: Live key configured"
else
    echo "   ⚠️  Stripe: Not configured (remember to set)"
fi
if [ "$deploy_confirm" = "yes" ]; then
    echo "   ✅ Functions deployed"
else
    echo "   ⚠️  Functions: Not deployed (remember to deploy)"
fi
echo ""
echo "📝 Next steps:"
echo "   1. Verify Firestore 'stripecheckouturl' is updated with live URL"
echo "   2. Test a real purchase with a real payment method"
echo "   3. Monitor logs: firebase functions:log"
echo "   4. Check Stripe dashboard for incoming payments"
echo ""
echo "📖 For detailed instructions, see: PRODUCTION_SETUP_GUIDE.md"
echo ""
echo "🔄 To rollback to test mode:"
echo "   firebase functions:config:set apple.environment=\"SANDBOX\""
echo "   firebase deploy --only functions"
echo ""

