# Clean Up Duplicate Invoices

## Problem
You have duplicate invoices in Firestore (5 copies of invoice #004).

## Solution

### Option 1: Delete via Firebase Console (Recommended)
1. Go to https://console.firebase.google.com
2. Select your project: `invoice-8b29c`
3. Navigate to **Firestore Database**
4. Click on the `invoices` collection
5. You'll see all invoice documents
6. **Delete the duplicate ones** (keep only ONE of each unique invoice)
7. Refresh your app - duplicates should be gone

### Option 2: Delete ALL invoices and start fresh
If you want to clear everything:

1. Go to Firestore Console
2. Select the `invoices` collection
3. Click the **three dots (⋮)** next to the collection name
4. Select **Delete collection**
5. Confirm deletion
6. Your app will now show the empty state
7. Create a new invoice - it will be the ONLY one

## Why Did Duplicates Happen?

The duplicates occurred because:
- Each invoice had a new UUID when created
- But the invoice NUMBER was hardcoded to "004"
- When you sent the invoice multiple times, it created multiple Firestore documents

## Fixed Now ✅

The code now:
1. ✅ **Generates unique invoice numbers** based on timestamp
2. ✅ **Deduplicates by UUID** when displaying (so even if duplicates exist in DB, UI shows unique ones)
3. ✅ **Uses UUID as document ID** (prevents duplicates from same invoice)
4. ✅ **Shows empty state** when no invoices exist
5. ✅ **ALL data is real** from Firestore

## Test After Cleanup

1. Delete duplicates from Firestore Console
2. Open app → Should show empty state or unique invoices only
3. Create new invoice → Gets unique number (e.g., #847)
4. Send invoice → Creates ONE document in Firestore
5. Check Invoices tab → Shows the new invoice with real data

