const jwt = require("jsonwebtoken");

// Generate JWT token for Apple API authentication
function generateAppleJWT({ keyId, issuerId, privateKey, bundleId }) {
  try {
    if (!keyId || !issuerId || !privateKey) {
      throw new Error("Missing Apple API configuration secrets");
    }

    const now = Math.floor(Date.now() / 1000);
    const payload = {
      iss: issuerId,
      iat: now,
      exp: now + 3600, // Token expires in 1 hour
      aud: "appstoreconnect-v1",
      bid: bundleId,
    };

    const token = jwt.sign(payload, privateKey, {
      algorithm: "ES256",
      header: {
        alg: "ES256",
        kid: keyId,
        typ: "JWT",
      },
    });

    console.log("🔐 Generated Apple JWT token successfully");
    return token;
  } catch (error) {
    console.error("❌ Error generating Apple JWT:", error);
    throw error;
  }
}

// Send consumption data to Apple
async function sendConsumptionDataToApple(
  transactionId,
  consumptionData,
  environment,
  auth
) {
  try {
    // Choose correct Apple endpoint based on environment
    const isProduction =
      String(environment).toUpperCase() === "PRODUCTION" ||
      String(environment).toUpperCase() === "PROD";
    const baseUrl = isProduction
      ? "https://api.storekit.itunes.apple.com"
      : "https://api.storekit-sandbox.itunes.apple.com";
    const appleEndpoint = `${baseUrl}/inApps/v1/transactions/consumption/${transactionId}`;

    try {
      // Generate JWT token for authentication
      const jwtToken = generateAppleJWT({
        keyId: auth && auth.keyId,
        issuerId: auth && auth.issuerId,
        privateKey: auth && auth.privateKey,
        bundleId: auth && auth.bundleId,
      });

      // Make authenticated request to Apple's API
      console.log("🔄 Sending consumption data to Apple API:", appleEndpoint);
      console.log("📊 Consumption data payload:", JSON.stringify(consumptionData, null, 2));
      
      if (consumptionData.customData) {
        console.log("💎 Custom usage data included:");
        console.log(`   - Total API Calls: ${consumptionData.customData.totalAPICallsMade}`);
        console.log(`   - Total Cost: $${(consumptionData.customData.totalCostCents / 100).toFixed(2)}`);
        console.log(`   - Features Used: ${consumptionData.customData.featuresUsed.join(", ")}`);
        console.log(`   - Features Created: ${consumptionData.customData.featuresCreated}`);
      }

      const response = await fetch(appleEndpoint, {
        method: "PUT",
        headers: {
          Authorization: `Bearer ${jwtToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(consumptionData),
      });

      const responseText = await response.text();

      if (response.ok) {
        console.log("✅ Successfully sent consumption data to Apple");
        return {
          success: true,
          payload: consumptionData,
          appleResponse: {
            status: response.status,
            body: responseText,
          },
        };
      } else {
        console.error(
          `❌ Apple API error: ${response.status} - ${responseText}`
        );
        return {
          success: false,
          payload: consumptionData,
          error: `Apple API error: ${response.status} - ${responseText}`,
        };
      }
    } catch (apiError) {
      console.error("❌ Error calling Apple API:", apiError);

      // Fall back to simulation if API call fails
      console.log(
        "🔄 [FALLBACK] Logging consumption data locally due to API error"
      );
      return {
        success: false,
        payload: consumptionData,
        error: apiError.message,
        fallbackUsed: true,
      };
    }
  } catch (error) {
    console.error("❌ Error sending consumption data to Apple:", error);
    throw error;
  }
}

module.exports = {
  sendConsumptionDataToApple,
};
