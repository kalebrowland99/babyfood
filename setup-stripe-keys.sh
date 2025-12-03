#!/bin/bash

echo "🔑 Stripe Keys Setup"
echo "===================="
echo ""
echo "This script will help you set up your Stripe keys for native payments."
echo ""
echo "📋 What you need:"
echo "1. Go to https://dashboard.stripe.com/test/apikeys"
echo "2. Make sure you're in TEST mode (toggle in top right)"
echo "3. Copy your 'Publishable key' (starts with pk_test_)"
echo "4. Copy your 'Secret key' (starts with sk_test_)"
echo ""

read -p "Press Enter when you're ready to continue..."

echo ""
echo "Setting TEST Publishable Key..."
firebase functions:secrets:set STRIPE_PUBLISHABLE_KEY_TEST

echo ""
echo "Setting TEST Secret Key..."
firebase functions:secrets:set STRIPE_SECRET_KEY_TEST

echo ""
echo "Setting TEST Webhook Secret (from Stripe Dashboard > Webhooks)..."
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET_TEST

echo ""
echo "✅ Keys configured!"
echo ""
echo "Now deploying the function..."
cd functions
firebase deploy --only functions:createStripePaymentSheet

echo ""
echo "🎉 Setup complete!"
echo ""
echo "You can now test native Stripe payments with:"
echo "  Card: 4242 4242 4242 4242"
echo "  Expiry: Any future date"
echo "  CVC: Any 3 digits"
echo ""

