#!/bin/bash

# Clear Thrifty app data without resetting the simulator
# Run this script anytime you want a fresh start

echo "🧹 Clearing Thrifty app data..."

# Get the app's data container path
APP_CONTAINER=$(xcrun simctl get_app_container booted com.thrifty.thrifty data 2>/dev/null)

if [ -z "$APP_CONTAINER" ]; then
    echo "❌ App not found. Make sure the app is installed on the booted simulator."
    exit 1
fi

echo "📍 App container: $APP_CONTAINER"

# Terminate the app if it's running
echo "🛑 Terminating app..."
xcrun simctl terminate booted com.thrifty.thrifty 2>/dev/null || true

# Clear UserDefaults (all .plist files)
echo "🗑️  Clearing UserDefaults..."
rm -f "$APP_CONTAINER/Library/Preferences/"*.plist 2>/dev/null || true

# Clear Caches
echo "🗑️  Clearing Caches..."
rm -rf "$APP_CONTAINER/Library/Caches/"* 2>/dev/null || true

# Clear tmp directory
echo "🗑️  Clearing tmp..."
rm -rf "$APP_CONTAINER/tmp/"* 2>/dev/null || true

# Clear Documents directory (optional - comment out if you want to keep user documents)
# echo "🗑️  Clearing Documents..."
# rm -rf "$APP_CONTAINER/Documents/"* 2>/dev/null || true

echo ""
echo "✅ All app data cleared!"
echo "📱 You can now relaunch the app from Xcode or the simulator"
echo ""
echo "Cleared:"
echo "  ✓ UserDefaults (stripeCheckoutOpened, pendingStripeSessionId, etc.)"
echo "  ✓ Caches"
echo "  ✓ Temporary files"
echo ""

