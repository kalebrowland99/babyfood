#!/bin/bash

# Setup Production Stripe Webhooks
# This script helps configure Stripe webhooks for production

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎣 Stripe Production Webhook Setup"
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

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1/3: Configure Webhook in Stripe Dashboard"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Instructions:"
echo "   1. Go to: https://dashboard.stripe.com/webhooks"
echo "   2. Make sure you're in LIVE mode (toggle in top right)"
echo "   3. Click '+ Add endpoint'"
echo "   4. Enter endpoint URL:"
echo "      https://stripewebhook-xhxqzuqe3q-uc.a.run.app"
echo "   5. Select these events:"
echo "      • checkout.session.completed"
echo "      • customer.subscription.created"
echo "      • customer.subscription.updated"
echo "      • customer.subscription.deleted"
echo "      • invoice.payment_succeeded"
echo "      • invoice.payment_failed"
echo "   6. Click 'Add endpoint'"
echo ""

read -p "Press Enter when you've created the webhook..."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2/3: Get Webhook Signing Secret"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Instructions:"
echo "   1. In Stripe Dashboard, click on the webhook you just created"
echo "   2. Find 'Signing secret' section"
echo "   3. Click 'Reveal'"
echo "   4. Copy the secret (starts with whsec_)"
echo ""

read -p "Do you have your webhook signing secret ready? (yes/no): " secret_ready

if [ "$secret_ready" = "yes" ]; then
    echo ""
    echo "🔐 Setting webhook secret in Firebase..."
    echo "   Paste your signing secret when prompted (whsec_...)"
    echo ""
    
    firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
    
    if [ $? -eq 0 ]; then
        echo "✅ Webhook secret configured successfully"
    else
        echo "❌ Failed to set webhook secret"
        exit 1
    fi
else
    echo "⏭️  Skipped webhook secret configuration"
    echo "⚠️  Remember to set it later with:"
    echo "   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET"
    exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3/3: Deploy Webhook Function"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Deploy the webhook function now? (yes/no): " deploy_confirm

if [ "$deploy_confirm" = "yes" ]; then
    echo "🚀 Deploying stripeWebhook function..."
    firebase deploy --only functions:stripeWebhook
    
    if [ $? -eq 0 ]; then
        echo "✅ Webhook function deployed successfully"
    else
        echo "❌ Failed to deploy webhook function"
        exit 1
    fi
else
    echo "⏭️  Skipped deployment"
    echo "⚠️  Remember to deploy later with:"
    echo "   firebase deploy --only functions:stripeWebhook"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Production Webhook Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Webhook endpoint configured in Stripe"
echo "✅ Webhook signing secret set in Firebase"
echo "✅ Webhook function deployed"
echo ""
echo "📝 Next steps:"
echo "   1. Test the webhook by sending a test event from Stripe Dashboard"
echo "   2. View logs: firebase functions:log --only stripeWebhook"
echo "   3. Make a real test purchase to verify end-to-end"
echo ""
echo "🔍 To verify setup:"
echo "   firebase functions:secrets:access STRIPE_WEBHOOK_SECRET"
echo ""

