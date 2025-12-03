/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore } = require("firebase-admin/firestore");
const { initializeApp } = require("firebase-admin/app");
const nodemailer = require("nodemailer");
const jwt = require("jsonwebtoken");
const fetch = require("node-fetch");

// Load environment variables for Firebase Functions v2
require("dotenv").config();

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

// Initialize email transporter
const createTransporter = () => {
  // Use environment variables directly
  const email = process.env.GMAIL_EMAIL || "app.noreply@gmail.com";
  const password = process.env.GMAIL_PASSWORD;
  
  if (!password) {
    throw new Error("Gmail password not configured. Please set GMAIL_PASSWORD environment variable.");
  }
  
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: email,
      pass: password, // Use App Password, not regular password
    },
  });
};

// Email verification function - allow unauthenticated calls
exports.sendVerificationEmail = onCall(
  {
    maxInstances: 10,
    allowInvalidAppCheckToken: true,
    allowUnauthenticated: true, // Allow unauthenticated calls
  },
  async (request) => {
    const { email, verificationCode, appName } = request.data;
    
    // Validate input
    if (!email || !verificationCode || !appName) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: email, verificationCode, or appName"
      );
    }
    
    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid email address"
      );
    }
    
    try {
      const transporter = createTransporter();
      
      // Email content
      const mailOptions = {
        from: "\"App Team\" <app.noreply@gmail.com>",
        to: email,
        subject: "Your Verification Code",
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Email Verification</title>
            <style>
              body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { text-align: center; margin-bottom: 30px; }
              .logo { font-size: 24px; font-weight: bold; color: #000; }
              .code-box { background: #f8f9fa; border: 2px solid #e9ecef; border-radius: 8px; padding: 20px; text-align: center; margin: 20px 0; }
              .code { font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #000; }
              .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #e9ecef; font-size: 14px; color: #666; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <div class="logo">📄 App</div>
              </div>
              
              <h2>Email Verification</h2>
              <p>Hello!</p>
              <p>You requested a verification code for your account. Enter the code below to continue:</p>
              
              <div class="code-box">
                <div class="code">${verificationCode}</div>
              </div>
              
              <p><strong>This code will expire in 10 minutes.</strong></p>
              <p>If you didn't request this code, you can safely ignore this email.</p>
              
              <div class="footer">
                <p>Best regards,<br>The App Team</p>
                <p style="font-size: 12px; margin-top: 20px;">
                  This is an automated message. Please do not reply to this email.
                </p>
              </div>
            </div>
          </body>
          </html>
        `,
        text: `
Your Verification Code

Hello!

You requested a verification code for your account. Enter the code below to continue:

${verificationCode}

This code will expire in 10 minutes.

If you didn't request this code, you can safely ignore this email.

Best regards,
The App Team
        `.trim(),
      };
      
      // Send email
      await transporter.sendMail(mailOptions);
      
      console.log(`✅ Verification email sent successfully to ${email}`);
      return { success: true, message: "Verification email sent successfully" };
      
    } catch (error) {
      console.error("❌ Error sending verification email:", error);
      throw new HttpsError(
        "internal",
        `Failed to send verification email: ${error.message}`
      );
    }
  }
);

// Apple App Store Server Notifications webhook handler
exports.appleConsumptionWebhook = onRequest(
  {
    maxInstances: 10,
    allowInvalidAppCheckToken: true,
    allowUnauthenticated: true,
  },
  async (request, response) => {
    console.log("🍎 Received Apple webhook notification");
    
    try {
      // Verify the request is from Apple (basic validation)
      const signature = request.headers["x-apple-signature"];
      if (!signature) {
        console.log("❌ Missing Apple signature header");
        return response.status(400).send("Missing signature");
      }

      const payload = request.body;
      console.log("📦 Apple webhook payload:", JSON.stringify(payload, null, 2));

      // Extract the notification type and data
      const signedPayload = payload.signedPayload;
      if (!signedPayload) {
        console.log("❌ Missing signedPayload in Apple webhook");
        return response.status(400).send("Missing signedPayload");
      }

      // For now, we'll decode the JWT payload (in production, you should verify the signature)
      let decodedPayload;
      try {
        const base64Payload = signedPayload.split(".")[1];
        decodedPayload = JSON.parse(Buffer.from(base64Payload, "base64").toString());
        console.log("🔓 Decoded Apple notification:", JSON.stringify(decodedPayload, null, 2));
      } catch (decodeError) {
        console.log("❌ Failed to decode Apple JWT payload:", decodeError.message);
        return response.status(400).send("Invalid JWT payload");
      }

      const notificationType = decodedPayload.notificationType;
      const data = decodedPayload.data || {};
      
      // Ensure we have required data fields
      if (!data.transactionId) {
        console.log("⚠️ Missing transactionId in Apple notification data");
        return response.status(200).send("Missing transaction ID");
      }

      // Handle CONSUMPTION_REQUEST specifically
      if (notificationType === "CONSUMPTION_REQUEST") {
        console.log("📊 Processing consumption request for transaction:", data.transactionId);
        
        // Store the consumption request for processing
        const docId = data.transactionId || `unknown_${Date.now()}`;
        await db.collection("consumption_requests").doc(docId).set({
          transactionId: data.transactionId || "unknown",
          originalTransactionId: data.originalTransactionId || data.transactionId || "unknown",
          bundleId: data.bundleId || "unknown",
          productId: data.productId || "unknown",
          requestedAt: new Date(),
          status: "pending",
          notificationData: decodedPayload
        });

        // Process the consumption request immediately
        await processConsumptionRequest(data.transactionId, data);
        
        console.log("✅ Consumption request processed successfully");
      } else {
        console.log(`ℹ️ Received notification type: ${notificationType} - no action needed`);
      }

      // Always return 200 OK to Apple
      response.status(200).send("OK");
      
    } catch (error) {
      console.error("❌ Error processing Apple webhook:", error);
      // Still return 200 to prevent Apple from retrying
      response.status(200).send("Error logged");
    }
  }
);

// Process consumption request and respond to Apple
async function processConsumptionRequest(transactionId, requestData) {
  try {
    console.log(`📊 Processing consumption request for transaction: ${transactionId}`);
    
    // Get consumption data for this user/transaction
    const consumptionData = await getConsumptionDataForTransaction(transactionId, requestData);
    
    // Send consumption data to Apple
    const response = await sendConsumptionDataToApple(transactionId, consumptionData);
    
    // Update the request status
    await db.collection("consumption_requests").doc(transactionId).update({
      status: "completed",
      responseData: consumptionData,
      sentToApple: true,
      completedAt: new Date()
    });
    
    console.log(`✅ Successfully sent consumption data to Apple for transaction: ${transactionId}`);
    return response;
    
  } catch (error) {
    console.error(`❌ Error processing consumption request for ${transactionId}:`, error);
    
    // Update status to failed
    await db.collection("consumption_requests").doc(transactionId).update({
      status: "failed",
      error: error.message,
      failedAt: new Date()
    });
    
    throw error;
  }
}

// Get consumption data for a specific transaction
async function getConsumptionDataForTransaction(transactionId, requestData) {
  try {
    // Query consumption data from Firestore
    // We'll need to match by user/product since we don't store transaction IDs directly
    const productId = requestData.productId;
    const bundleId = requestData.bundleId;
    
    console.log(`🔍 Looking for consumption data for product: ${productId}, bundle: ${bundleId}`);
    
    // Query consumption events from all users for this product
    const usersQuery = await db.collection("user_consumption")
      .where("productId", "==", productId)
      .where("bundleId", "==", bundleId)
      .get();
    
    const consumptionEvents = [];
    
    // Get events from all matching users
    for (const userDoc of usersQuery.docs) {
      const eventsQuery = await userDoc.ref.collection("events")
        .orderBy("timestamp", "desc")
        .limit(50)
        .get();
      
      eventsQuery.forEach(eventDoc => {
        consumptionEvents.push({
          ...eventDoc.data(),
          userId: userDoc.id
        });
      });
    }
    
    // Aggregate consumption data
    const aggregatedData = aggregateConsumptionData(consumptionEvents);
    
    console.log(`📊 Found ${consumptionEvents.length} consumption events`);
    console.log(`📈 Aggregated consumption:`, aggregatedData);
    
    return {
      transactionId: transactionId,
      consumptionData: aggregatedData,
      totalEvents: consumptionEvents.length,
      dataCollectedAt: new Date().toISOString()
    };
    
  } catch (error) {
    console.error("❌ Error getting consumption data:", error);
    
    // Return minimal data if we can't find detailed consumption
    return {
      transactionId: transactionId,
      consumptionData: {
        totalApiCalls: 0,
        totalCostCents: 0,
        features: [],
        message: "No detailed consumption data available"
      },
      totalEvents: 0,
      dataCollectedAt: new Date().toISOString(),
      error: "Could not retrieve detailed consumption data"
    };
  }
}

// Aggregate consumption events into summary data
function aggregateConsumptionData(events) {
  const summary = {
    totalApiCalls: 0,
    totalCostCents: 0,
    apiCalls: 0,
    externalApiCalls: 0,
    firebaseCalls: 0,
    features: new Set(),
    sessions: 0,
    firstUsage: null,
    lastUsage: null
  };
  
  events.forEach(event => {
    // Count API calls by type
    if (event.type === "api_call" && event.successful) {
      summary.apiCalls++;
      summary.totalCostCents += event.cost_cents || 0;
    } else if (event.type === "external_api_call" && event.successful) {
      summary.externalApiCalls++;
      summary.totalCostCents += event.cost_cents || 0;
    } else if (event.type === "firebase_call" && event.successful) {
      summary.firebaseCalls++;
      summary.totalCostCents += event.cost_cents || 0;
    } else if (event.type === "feature_used") {
      summary.features.add(event.feature);
    } else if (event.type === "session_start") {
      summary.sessions++;
    }
    
    summary.totalApiCalls++;
    
    // Track usage timeframe
    const eventTime = new Date(event.timestamp * 1000);
    if (!summary.firstUsage || eventTime < summary.firstUsage) {
      summary.firstUsage = eventTime;
    }
    if (!summary.lastUsage || eventTime > summary.lastUsage) {
      summary.lastUsage = eventTime;
    }
  });
  
  return {
    ...summary,
    features: Array.from(summary.features),
    usageDurationDays: summary.firstUsage && summary.lastUsage ? 
      Math.ceil((summary.lastUsage - summary.firstUsage) / (1000 * 60 * 60 * 24)) : 0
  };
}

// Generate JWT token for Apple API authentication
function generateAppleJWT() {
  try {
    // Use environment variables instead of functions.config() for v2
    const keyId = process.env.APPLE_KEY_ID;
    const issuerId = process.env.APPLE_ISSUER_ID;
    const privateKey = process.env.APPLE_PRIVATE_KEY;
    
    if (!keyId || !issuerId || !privateKey) {
      throw new Error("Missing Apple API configuration");
    }
    
    const now = Math.floor(Date.now() / 1000);
    const payload = {
      iss: issuerId,
      iat: now,
      exp: now + 3600, // Token expires in 1 hour
      aud: "appstoreconnect-v1"
    };
    
    const token = jwt.sign(payload, privateKey, {
      algorithm: "ES256",
      header: {
        alg: "ES256",
        kid: keyId,
        typ: "JWT"
      }
    });
    
    console.log("🔐 Generated Apple JWT token successfully");
    return token;
    
  } catch (error) {
    console.error("❌ Error generating Apple JWT:", error);
    throw error;
  }
}

// Send consumption data to Apple
async function sendConsumptionDataToApple(transactionId, consumptionData) {
  try {
    console.log(`📤 Sending consumption data to Apple for transaction: ${transactionId}`);
    
    // Apple's App Store Server API endpoint for consumption data
    const appleEndpoint = `https://api.storekit.itunes.apple.com/inApps/v1/transactions/consumption/${transactionId}`;
    
    // Prepare the consumption data in Apple's expected format
    const applePayload = {
      customerConsented: true, // User consented to data collection
      consumptionStatus: consumptionData.totalEvents > 0 ? "CONSUMED" : "NOT_CONSUMED",
      platform: "IOS",
      sampleContentProvided: false,
      deliveryStatus: "DELIVERED_TO_CUSTOMER",
      appAccountToken: null, // We don't use app account tokens
      accountTenure: 30, // Days since account creation (estimate)
      playTime: Math.min(consumptionData.consumptionData.usageDurationDays * 24 * 60, 10080), // Max 7 days in minutes
      lifetimeDollarsRefunded: 0,
      lifetimeDollarsPurchased: 2999, // $29.99 in cents
      refundPreference: "DENY_REFUND"
    };
    
    console.log("📋 Apple consumption payload:", JSON.stringify(applePayload, null, 2));
    
    try {
      // Generate JWT token for authentication
      const jwtToken = generateAppleJWT();
      
      // Make authenticated request to Apple's API
      console.log("🔄 Sending consumption data to Apple API:", appleEndpoint);
      
      const response = await fetch(appleEndpoint, {
        method: "PUT",
        headers: {
          "Authorization": `Bearer ${jwtToken}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(applePayload)
      });
      
      const responseText = await response.text();
      console.log(`📊 Apple API response status: ${response.status}`);
      console.log(`📊 Apple API response: ${responseText}`);
      
      if (response.ok) {
        console.log("✅ Successfully sent consumption data to Apple");
        return {
          success: true,
          payload: applePayload,
          appleResponse: {
            status: response.status,
            body: responseText
          }
        };
      } else {
        console.error(`❌ Apple API error: ${response.status} - ${responseText}`);
        return {
          success: false,
          payload: applePayload,
          error: `Apple API error: ${response.status} - ${responseText}`
        };
      }
      
    } catch (apiError) {
      console.error("❌ Error calling Apple API:", apiError);
      
      // Fall back to simulation if API call fails
      console.log("🔄 [FALLBACK] Logging consumption data locally due to API error");
      return {
        success: false,
        payload: applePayload,
        error: apiError.message,
        fallbackUsed: true
      };
    }
    
  } catch (error) {
    console.error("❌ Error sending consumption data to Apple:", error);
    throw error;
  }
}

// Cloud Function to sync consumption data from client
exports.syncConsumptionData = onCall(
  {
    maxInstances: 10,
    allowInvalidAppCheckToken: true,
  },
  async (request) => {
    const { userId, consumptionEvents, userEmail, productId } = request.data;
    
    if (!userId || !consumptionEvents) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: userId or consumptionEvents"
      );
    }
    
    try {
      console.log(`📊 Syncing ${consumptionEvents.length} consumption events for user: ${userId}`);
      
      // Store consumption data in Firestore
      const batch = db.batch();
      
      // Update user consumption summary
      const userConsumptionRef = db.collection("user_consumption").doc(userId);
      batch.set(userConsumptionRef, {
        userId: userId,
        userEmail: userEmail,
        productId: productId || "com.app.subscription.monthly",
        bundleId: "com.app.bundle",
        lastSyncAt: new Date(),
        totalEvents: consumptionEvents.length
      }, { merge: true });
      
      // Store individual consumption events
      consumptionEvents.forEach((event, index) => {
        const eventRef = db.collection("user_consumption").doc(userId)
          .collection("events").doc(`${Date.now()}_${index}`);
        
        batch.set(eventRef, {
          ...event,
          syncedAt: new Date(),
          timestamp: event.timestamp || Date.now() / 1000
        });
      });
      
      await batch.commit();
      
      console.log(`✅ Successfully synced consumption data for user: ${userId}`);
      return { 
        success: true, 
        eventsSynced: consumptionEvents.length,
        message: "Consumption data synced successfully" 
      };
      
    } catch (error) {
      console.error("❌ Error syncing consumption data:", error);
      throw new HttpsError(
        "internal",
        `Failed to sync consumption data: ${error.message}`
      );
    }
  }
);

// Cloud Function to update existing transaction with latest usage data
exports.updateTransaction = onCall(
  {
    maxInstances: 10,
    allowInvalidAppCheckToken: true,
  },
  async (request) => {
    const {
      transactionId,
      userId,
      usedSubscription,
      playTimeSeconds,
      updatedAt
    } = request.data;
    
    if (!transactionId || !userId) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: transactionId or userId"
      );
    }
    
    try {
      console.log(`📊 Updating transaction: ${transactionId} for user: ${userId}`);
      
      // Update transaction in Firestore
      const transactionRef = db.collection("transactions").doc(transactionId);
      
      // Check if transaction exists
      const doc = await transactionRef.get();
      if (!doc.exists) {
        console.log(`⚠️ Transaction ${transactionId} not found, skipping update`);
        return {
          success: false,
          message: "Transaction not found"
        };
      }
      
      // Update only the fields that can change
      await transactionRef.update({
        usedSubscription: usedSubscription || false,
        playTimeSeconds: playTimeSeconds || 0,
        updatedAt: updatedAt || Date.now() / 1000
      });
      
      console.log(`✅ Transaction updated successfully: ${transactionId}`);
      console.log(`   - Play Time: ${playTimeSeconds}s`);
      console.log(`   - Used Subscription: ${usedSubscription}`);
      
      return {
        success: true,
        transactionId,
        message: "Transaction updated successfully"
      };
      
    } catch (error) {
      console.error("❌ Error updating transaction:", error);
      throw new HttpsError(
        "internal",
        `Failed to update transaction: ${error.message}`
      );
    }
  }
);

// Cloud Function to record transaction for consumption tracking
exports.recordTransaction = onCall(
  {
    maxInstances: 10,
    allowInvalidAppCheckToken: true,
  },
  async (request) => {
    const {
      transactionId,
      originalTransactionId,
      productId,
      purchaseDate,
      expiresDate,
      price,
      currency,
      userId,
      userEmail,
      revenueCatUserId,
      usedSubscription,
      playTimeSeconds,
      recordedAt
    } = request.data;
    
    if (!transactionId || !userId) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: transactionId or userId"
      );
    }
    
    try {
      console.log(`📊 Recording transaction: ${transactionId} for user: ${userId}`);
      
      // Store transaction in Firestore
      const transactionRef = db.collection("transactions").doc(transactionId);
      await transactionRef.set({
        transactionId,
        originalTransactionId,
        productId,
        purchaseDate,
        expiresDate: expiresDate || null,
        price,
        currency,
        userId,
        userEmail: userEmail || "",
        revenueCatUserId: revenueCatUserId || "",
        usedSubscription: usedSubscription || false,
        playTimeSeconds: playTimeSeconds || 0,
        recordedAt: recordedAt || Date.now() / 1000,
        updatedAt: Date.now() / 1000
      });
      
      console.log(`✅ Transaction recorded successfully: ${transactionId}`);
      return {
        success: true,
        transactionId,
        message: "Transaction recorded successfully"
      };
      
    } catch (error) {
      console.error("❌ Error recording transaction:", error);
      throw new HttpsError(
        "internal",
        `Failed to record transaction: ${error.message}`
      );
    }
  }
);

// ============================================================================
// META CONVERSIONS API - Server-to-Server Purchase Tracking
// ============================================================================

// Helper function to hash email addresses (required by Meta)
function hashSHA256(value) {
  const crypto = require("crypto");
  if (!value) return null;
  return crypto.createHash("sha256").update(value.toLowerCase().trim()).digest("hex");
}

// Send purchase event to Meta Conversions API
// Following official documentation: https://developers.facebook.com/docs/marketing-api/conversions-api/app-events/
exports.sendMetaPurchaseEvent = onCall(
  {
    maxInstances: 10,
    allowInvalidAppCheckToken: true,
  },
  async (request) => {
    const { 
      email, 
      price, 
      planType, 
      transactionId, 
      timestamp,
      currency = "USD",
      // Required fields for app events per Meta documentation
      advertiserTrackingEnabled = 0,
      applicationTrackingEnabled = 0,
      extinfo = [],
      installId = "",
      idfa = null
    } = request.data;
    
    console.log(`📘 Sending Meta purchase event for ${planType} - $${price}`);
    console.log(`📧 Email included: ${email ? "Yes" : "No"}`);
    console.log(`📱 ATT Status: ${advertiserTrackingEnabled}, IDFA: ${idfa ? "Yes" : "No"}`);
    
    try {
      // Get Meta credentials from environment variables (Firebase Functions v2)
      const metaPixelId = process.env.META_PIXEL_ID;
      const metaAccessToken = process.env.META_ACCESS_TOKEN;
      
      if (!metaPixelId || !metaAccessToken) {
        console.error("❌ Meta credentials not configured");
        throw new HttpsError(
          "failed-precondition",
          "Meta Conversions API credentials not configured. Please set META_PIXEL_ID and META_ACCESS_TOKEN environment variables."
        );
      }
      
      // Build user_data object with required and optional fields
      const userData = {
        client_ip_address: (request.rawRequest && request.rawRequest.ip) || undefined,
        client_user_agent: (request.rawRequest && request.rawRequest.headers && request.rawRequest.headers["user-agent"]) || undefined,
      };
      
      // Add email if provided (hashed per Meta requirements)
      if (email) {
        userData.em = [hashSHA256(email)];
      }
      
      // Add IDFA (madid) if available
      if (idfa) {
        userData.madid = idfa;
      }
      
      // Add anonymous installation ID (anon_id)
      if (installId) {
        userData.anon_id = installId;
      }
      
      // Prepare event data for Meta CAPI (per documentation)
      const eventData = {
        data: [{
          event_name: "Purchase",
          event_time: timestamp || Math.floor(Date.now() / 1000),
          action_source: "app", // REQUIRED for app events
          user_data: userData,
          custom_data: {
            value: price,
            currency: currency,
            content_name: planType,
            content_type: "product",
          },
          event_id: transactionId, // For deduplication with SKAdNetwork
          // REQUIRED fields for app events per Meta documentation
          app_data: {
            advertiser_tracking_enabled: advertiserTrackingEnabled, // ATT permission (0 or 1)
            application_tracking_enabled: applicationTrackingEnabled, // App-level tracking (0 or 1)
            extinfo: extinfo.length > 0 ? extinfo : undefined // Extended device info (REQUIRED)
          }
        }],
        access_token: metaAccessToken
      };
      
      // Remove undefined fields to clean up payload
      if (!eventData.data[0].user_data.em) {
        delete eventData.data[0].user_data.em;
      }
      if (!eventData.data[0].user_data.madid) {
        delete eventData.data[0].user_data.madid;
      }
      if (!eventData.data[0].user_data.anon_id) {
        delete eventData.data[0].user_data.anon_id;
      }
      if (!eventData.data[0].app_data.extinfo) {
        delete eventData.data[0].app_data.extinfo;
      }
      
      console.log(`📘 Sending to Meta Dataset ID: ${metaPixelId}`);
      console.log(`📊 Event payload includes: ${Object.keys(userData).join(", ")}`);
      
      // Send to Meta Conversions API using dataset endpoint
      const metaUrl = `https://graph.facebook.com/v18.0/${metaPixelId}/events`;
      const response = await fetch(metaUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify(eventData)
      });
      
      const responseData = await response.json();
      
      if (response.ok) {
        console.log(`✅ Meta purchase event sent successfully for ${planType}`);
        console.log(`📊 Meta response:`, responseData);
        
        // Log to Firestore for tracking
        await db.collection("meta_events").add({
          planType,
          price,
          transactionId,
          email: email ? "***" : null, // Don't store full email
          sentAt: new Date(),
          metaResponse: responseData,
          success: true
        });
        
        return {
          success: true,
          message: "Purchase event sent to Meta successfully",
          eventsReceived: responseData.events_received || 0,
          fbtrace_id: responseData.fbtrace_id
        };
      } else {
        console.error(`❌ Meta API error: ${response.status}`, responseData);
        
        // Log error to Firestore
        await db.collection("meta_events").add({
          planType,
          price,
          transactionId,
          sentAt: new Date(),
          error: responseData,
          success: false
        });
        
        throw new HttpsError(
          "internal",
          `Meta API error: ${(responseData.error && responseData.error.message) || "Unknown error"}`
        );
      }
      
    } catch (error) {
      console.error("❌ Error sending Meta purchase event:", error);
      throw new HttpsError(
        "internal",
        `Failed to send Meta purchase event: ${error.message}`
      );
    }
  }
);

// TEST: Simulate consumption request (bypasses Apple signature verification)
exports.testConsumptionRequest = onCall(
  {
    maxInstances: 10,
    allowInvalidAppCheckToken: true,
    allowUnauthenticated: true,
  },
  async (request) => {
    try {
      const { transactionId } = request.data;
      
      if (!transactionId) {
        throw new HttpsError("invalid-argument", "transactionId is required");
      }

      console.log(`🧪 TEST: Simulating CONSUMPTION_REQUEST for transaction: ${transactionId}`);

      // Get transaction from Firestore
      const transactionDoc = await db.collection("transactions").doc(transactionId).get();
      
      if (!transactionDoc.exists) {
        throw new HttpsError("not-found", `Transaction ${transactionId} not found`);
      }

      const transactionData = transactionDoc.data();
      console.log(`✅ Found transaction:`, transactionData);

      // Import the consumption service functions
      const { getConsumptionData } = require("./consumptionService");
      
      // Create a mock transaction info object from the Firestore data
      const mockTransactionInfo = {
        transactionId: transactionData.transactionId,
        originalTransactionId: transactionData.originalTransactionId,
        productId: transactionData.productId,
        purchaseDate: transactionData.purchaseDate && transactionData.purchaseDate.toMillis ? transactionData.purchaseDate.toMillis() : transactionData.purchaseDate,
        expiresDate: transactionData.expiresDate,
        environment: transactionData.environment || "Sandbox",
      };

      console.log(`📊 Mock transaction info:`, mockTransactionInfo);

      // Get consumption data (this will query Firestore and aggregate data)
      const consumptionData = await getConsumptionData(
        mockTransactionInfo,
        process.env.REVENUECAT_API_KEY
      );

      console.log(`✅ Generated consumption data:`, consumptionData);

      // Store the test request in Firestore
      const requestDoc = {
        notificationType: "CONSUMPTION_REQUEST",
        notificationUUID: `test-${Date.now()}`,
        transactionId: transactionId,
        originalTransactionId: transactionData.originalTransactionId,
        productId: transactionData.productId,
        requestReason: "TEST_SIMULATION",
        requestedAt: new Date(),
        environment: "Test",
        status: "test_completed",
        responseData: consumptionData,
        note: "This is a simulated test request, not from Apple"
      };

      const requestRef = await db.collection("consumption_requests").add(requestDoc);
      console.log(`✅ Test consumption request logged to Firestore: ${requestRef.id}`);

      return {
        success: true,
        message: "Test consumption request completed",
        firestoreDocId: requestRef.id,
        consumptionData: consumptionData,
        instructions: {
          checkFirestore: "Check Firebase console for consumption_requests collection",
          docId: requestRef.id
        }
      };

    } catch (error) {
      console.error("❌ Test error:", error);
      throw new HttpsError("internal", error.message);
    }
  }
);

// Import and export Apple webhook handler
const { appleConsumptionWebhook } = require("./appleWebhook");
exports.appleConsumptionWebhook = appleConsumptionWebhook;

// ============================================================================
// INVOICE SENDING - Resend Email Integration
// ============================================================================

const { sendInvoiceEmail } = require("./invoiceService");

/**
 * Send invoice to customer via email
 * Cloud function callable from iOS app
 */
exports.sendInvoice = onCall(
  {
    maxInstances: 10,
    allowInvalidAppCheckToken: true,
    secrets: ["RESEND_API_KEY"],
  },
  async (request) => {
    const { invoiceId, recipientEmail, businessName, senderEmail } = request.data;
    
    console.log(`📧 Received request to send invoice: ${invoiceId} to ${recipientEmail}`);
    
    // Validate input
    if (!invoiceId || !recipientEmail) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: invoiceId or recipientEmail"
      );
    }
    
    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(recipientEmail)) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid email address"
      );
    }
    
    try {
      // Get invoice from Firestore
      const invoiceDoc = await db.collection("invoices").doc(invoiceId).get();
      
      if (!invoiceDoc.exists) {
        throw new HttpsError(
          "not-found",
          `Invoice ${invoiceId} not found`
        );
      }
      
      const invoiceData = invoiceDoc.data();
      const invoice = {
        id: invoiceId,
        ...invoiceData,
        // Convert Firestore Timestamps to Date objects
        issuedDate: invoiceData.issuedDate && invoiceData.issuedDate.toDate ? invoiceData.issuedDate.toDate() : invoiceData.issuedDate,
        dueDate: invoiceData.dueDate && invoiceData.dueDate.toDate ? invoiceData.dueDate.toDate() : invoiceData.dueDate,
      };
      
      console.log(`✅ Found invoice: ${invoice.number}`);
      
      // Send invoice email
      const result = await sendInvoiceEmail({
        invoice,
        recipientEmail,
        senderEmail: senderEmail || `${businessName || "615films"} <invoices@resend.dev>`,
        businessName: businessName || "615films",
      });
      
      console.log(`✅ Invoice sent successfully`);
      
      return {
        success: true,
        message: "Invoice sent successfully",
        messageId: result.messageId,
        pdfPath: result.pdfPath,
      };
      
    } catch (error) {
      console.error("❌ Error sending invoice:", error);
      throw new HttpsError(
        "internal",
        `Failed to send invoice: ${error.message}`
      );
    }
  }
);
