#!/bin/bash

# Cal AI App - Validation Script
# Run this to check for common issues

MAIN_FILE="/Users/kaleb/Desktop/invoice/Invoice/ContentView.swift"
ERRORS=0

echo "🔍 Validating ContentView.swift..."
echo ""

# Check if file exists
if [ ! -f "$MAIN_FILE" ]; then
    echo "❌ Error: ContentView.swift not found!"
    exit 1
fi

# Check line count
LINE_COUNT=$(wc -l < "$MAIN_FILE")
echo "📝 Line count: $LINE_COUNT"
if [ $LINE_COUNT -lt 15000 ] || [ $LINE_COUNT -gt 17000 ]; then
    echo "⚠️  Warning: Line count is unusual (expected ~16,000)"
    ERRORS=$((ERRORS+1))
else
    echo "✅ Line count looks good"
fi
echo ""

# Check for duplicate struct declarations
echo "🔎 Checking for duplicate structs..."
DUPLICATES=$(grep "^struct " "$MAIN_FILE" | sort | uniq -d)
if [ -n "$DUPLICATES" ]; then
    echo "❌ Found duplicate struct declarations:"
    echo "$DUPLICATES"
    ERRORS=$((ERRORS+1))
else
    echo "✅ No duplicate structs found"
fi
echo ""

# Check for common wrong property names
echo "🔎 Checking for incorrect property names..."

WRONG_USER=$(grep -n "authManager\.user[^D]" "$MAIN_FILE" | grep -v "// " | head -3)
if [ -n "$WRONG_USER" ]; then
    echo "❌ Found 'authManager.user' (should be 'authManager.currentUser'):"
    echo "$WRONG_USER"
    ERRORS=$((ERRORS+1))
else
    echo "✅ No 'authManager.user' found"
fi

WRONG_SIGNOUT=$(grep -n "authManager\.signOut" "$MAIN_FILE" | grep -v "// " | head -3)
if [ -n "$WRONG_SIGNOUT" ]; then
    echo "❌ Found 'authManager.signOut' (should be 'authManager.logOut'):"
    echo "$WRONG_SIGNOUT"
    ERRORS=$((ERRORS+1))
else
    echo "✅ No 'authManager.signOut' found"
fi

WRONG_DISPLAYNAME=$(grep -n "\.displayName" "$MAIN_FILE" | grep -v "places\." | grep -v "firebaseUser\." | grep -v "// " | head -3)
if [ -n "$WRONG_DISPLAYNAME" ]; then
    echo "⚠️  Found '.displayName' usage (check if it should be '.name' for UserData):"
    echo "$WRONG_DISPLAYNAME"
fi
echo ""

# Check for essential components
echo "🔎 Checking for essential components..."

check_component() {
    local name=$1
    local pattern=$2
    if grep -q "$pattern" "$MAIN_FILE"; then
        echo "✅ $name found"
    else
        echo "❌ $name missing!"
        ERRORS=$((ERRORS+1))
    fi
}

check_component "AuthenticationManager" "^class AuthenticationManager"
check_component "MainAppView" "^struct MainAppView"
check_component "HomeView" "^struct HomeView"
check_component "ProfileView" "^struct ProfileView"
check_component "SubscriptionView" "^struct SubscriptionView"
echo ""

# Check for unclosed braces (simple check)
echo "🔎 Checking brace balance..."
OPEN_BRACES=$(grep -o "{" "$MAIN_FILE" | wc -l)
CLOSE_BRACES=$(grep -o "}" "$MAIN_FILE" | wc -l)
echo "Opening braces: $OPEN_BRACES"
echo "Closing braces: $CLOSE_BRACES"
DIFF=$((OPEN_BRACES - CLOSE_BRACES))
if [ $DIFF -eq 0 ]; then
    echo "✅ Braces are balanced"
elif [ $DIFF -gt -5 ] && [ $DIFF -lt 5 ]; then
    echo "⚠️  Brace difference: $DIFF (might be okay)"
else
    echo "❌ Brace mismatch: $DIFF difference!"
    ERRORS=$((ERRORS+1))
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ]; then
    echo "✅ Validation passed! No critical issues found."
else
    echo "❌ Found $ERRORS issue(s) that need attention."
    echo ""
    echo "💡 Tips:"
    echo "  - Review the issues above"
    echo "  - Check QUICK_REFERENCE.md for fixes"
    echo "  - Restore from backup if needed"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
