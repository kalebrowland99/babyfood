#!/bin/bash
# Measure build time for your project
echo "🔍 Measuring build time..."
echo "🧹 Cleaning build folder..."
xcodebuild -project Invoice.xcodeproj -scheme Thrifty -sdk iphonesimulator clean > /dev/null 2>&1

echo "⏱️  Starting timed build..."
time xcodebuild -project Invoice.xcodeproj -scheme Thrifty -sdk iphonesimulator -configuration Debug build -quiet

echo ""
echo "✅ Build complete! Check the time above."
echo ""
echo "💡 To see which files are slowest:"
echo "   xcodebuild -project Invoice.xcodeproj -scheme Thrifty -sdk iphonesimulator build OTHER_SWIFT_FLAGS=\"-Xfrontend -debug-time-function-bodies\" | grep -E '[0-9]+\.[0-9]+ms' | sort -rn | head -20"
