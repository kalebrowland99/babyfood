#!/bin/bash

# Cal AI App - Backup Script
# Run this before making any major changes

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/Users/kaleb/Desktop/invoice/Invoice"
MAIN_FILE="$BACKUP_DIR/ContentView.swift"
BACKUP_FILE="$BACKUP_DIR/ContentView.swift.backup_$DATE"

echo "📦 Creating backup of ContentView.swift..."

if [ -f "$MAIN_FILE" ]; then
    cp "$MAIN_FILE" "$BACKUP_FILE"
    echo "✅ Backup created: ContentView.swift.backup_$DATE"
    echo "📊 File size: $(du -h $BACKUP_FILE | cut -f1)"
    echo "📝 Line count: $(wc -l < $MAIN_FILE) lines"
    
    # Keep only the 5 most recent backups to save space
    echo ""
    echo "🧹 Cleaning old backups (keeping 5 most recent)..."
    cd "$BACKUP_DIR"
    ls -t ContentView.swift.backup_* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null
    
    echo ""
    echo "📁 Current backups:"
    ls -lht ContentView.swift.backup_* 2>/dev/null | head -5
else
    echo "❌ Error: ContentView.swift not found!"
    exit 1
fi
