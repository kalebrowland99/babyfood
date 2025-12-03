/**
 * Firebase Setup Script for Dynamic Pricing Configuration
 * 
 * This script sets up the required Firestore document for dynamic pricing control.
 * Run this once to create the initial configuration.
 */

const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json'); // You'll need to download this from Firebase Console

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function setupDynamicPricing() {
  console.log('🚀 Setting up dynamic pricing configuration...\n');

  try {
    // Create the paywall_config document with dynamic pricing fields
    const configRef = db.collection('app_config').doc('paywall_config');
    
    // Check if document already exists
    const doc = await configRef.get();
    
    if (doc.exists) {
      console.log('📄 Document already exists. Updating with new pricing fields...\n');
      
      // Update existing document with new fields
      await configRef.update({
        '9dollarpricing': false, // Start with false (use old pricing)
        newmainpriceid: 'price_1Sa0MTEAO5iISw7SKeYn77np', // $9.99 main
        newwinbackpriceid: 'price_1Sa0NTEAO5iISw7Sic1M8dOC', // $4.99 winback
        removetrial: false, // Start with false (include 3-day trial)
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log('✅ Updated existing configuration with new pricing fields\n');
    } else {
      console.log('📝 Creating new paywall_config document...\n');
      
      // Create new document with all fields
      await configRef.set({
        // Existing fields (if you have them)
        hardpaywall: true,
        stripepaywall: false,
        usestripesheet: false,
        useproductionmode: true,
        cancelsubscription: false,
        
        // New dynamic pricing fields
        '9dollarpricing': false, // Start with false (use old pricing)
        newmainpriceid: 'price_1Sa0MTEAO5iISw7SKeYn77np', // $9.99 main
        newwinbackpriceid: 'price_1Sa0NTEAO5iISw7Sic1M8dOC', // $4.99 winback
        removetrial: false, // Start with false (include 3-day trial)
        
        // Metadata
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log('✅ Created new configuration document\n');
    }

    // Fetch and display current configuration
    const updatedDoc = await configRef.get();
    const data = updatedDoc.data();
    
    console.log('📊 Current Configuration:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('Dynamic Pricing Settings:');
    console.log(`  • Use $9 Pricing: ${data['9dollarpricing']}`);
    console.log(`  • New Main Price ID: ${data.newmainpriceid} ($9.99)`);
    console.log(`  • New Winback Price ID: ${data.newwinbackpriceid} ($4.99)`);
    console.log(`  • Remove Trial: ${data.removetrial} (${data.removetrial ? 'NO trial' : '3-day trial'})`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    console.log('🎉 Setup Complete!\n');
    console.log('📝 Next Steps:');
    console.log('  1. Deploy your Firebase functions (if not already done)');
    console.log('  2. Test with 9dollarpricing = false (old pricing)');
    console.log('  3. When ready, set 9dollarpricing = true via Firebase Console');
    console.log('  4. To remove trial, set removetrial = true');
    console.log('  5. Monitor conversion metrics\n');
    
    console.log('🔗 To change configuration:');
    console.log('  1. Go to Firebase Console → Firestore Database');
    console.log('  2. Navigate to app_config/paywall_config');
    console.log('  3. Edit fields:');
    console.log('     - 9dollarpricing: switch pricing tiers');
    console.log('     - removetrial: toggle trial period');
    console.log('  4. Save changes (takes effect immediately!)\n');

  } catch (error) {
    console.error('❌ Error setting up configuration:', error);
    process.exit(1);
  }

  process.exit(0);
}

// Run the setup
setupDynamicPricing();

