const { db } = require("./utils");
const { getAuth } = require("firebase-admin/auth");
const { RevenueCatService } = require("./revenueCatService");

/**
 * Compute Apple's accountTenure bucket from an account age in days.
 * Buckets (inclusive of lower bound, exclusive of upper where applicable):
 * 0: undeclared
 * 1: 0–3 days
 * 2: 3–10 days
 * 3: 10–30 days
 * 4: 30–90 days
 * 5: 90–180 days
 * 6: 180–365 days
 * 7: > 365 days
 */
function mapDaysToAccountTenure(accountAgeDays) {
  if (accountAgeDays == null || Number.isNaN(accountAgeDays)) {
    return 0;
  }
  if (accountAgeDays < 3) return 1;
  if (accountAgeDays < 10) return 2;
  if (accountAgeDays < 30) return 3;
  if (accountAgeDays < 90) return 4;
  if (accountAgeDays < 180) return 5;
  if (accountAgeDays < 365) return 6;
  return 7;
}

/**
 * Parse a date value that may be milliseconds (number) or date string.
 * Returns epoch milliseconds or null if invalid.
 * @param {number|string|null|undefined} value
 * @returns {number|null}
 */
function parseEpochMillis(value) {
  if (value == null) return null;
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  const parsed = Date.parse(String(value));
  return Number.isNaN(parsed) ? null : parsed;
}

/**
 * Map to Apple's int32 consumptionStatus based on purchase and expiry time.
 * 0 undeclared; 1 not consumed; 2 partially consumed; 3 fully consumed.
 * - If now < purchase -> NOT_CONSUMED (1)
 * - If purchase <= now < expire -> PARTIALLY_CONSUMED (2)
 * - If now >= expire -> FULLY_CONSUMED (3)
 * Any missing/invalid times -> 0 (undeclared)
 * @param {number|string|null} purchaseDate
 * @param {number|string|null} expiresDate
 * @param {number} [nowMs]
 * @returns {0|1|2|3}
 */
function mapConsumptionStatus(purchaseDate, expiresDate, usedSubscription) {
  const purchaseMs = parseEpochMillis(purchaseDate);
  const expiresMs = parseEpochMillis(expiresDate);
  if (purchaseMs == null || expiresMs == null) {
    return 0;
  }
  const nowMs = new Date();

  if (!usedSubscription) return 1;
  if (nowMs < purchaseMs) return 1; // not consumed
  if (nowMs >= expiresMs) return 3; // fully consumed
  return 2; // partially consumed
}

/**
 * Map engagement time in minutes to Apple's int32 playTime bucket.
 * Buckets:
 * 0: undeclared
 * 1: 0–5 minutes
 * 2: 5–60 minutes
 * 3: 1–6 hours
 * 4: 6–24 hours
 * 5: 1–4 days
 * 6: 4–16 days
 * 7: over 16 days
 * @param {number|null|undefined} minutes
 * @returns {0|1|2|3|4|5|6|7}
 */
function mapPlayTimeMinutes(minutes) {
  if (minutes == null || !Number.isFinite(minutes) || minutes < 0) return 0;
  if (minutes < 5) return 1; // 0–5 minutes
  if (minutes < 60) return 2; // 5–60 minutes
  if (minutes < 6 * 60) return 3; // 1–6 hours
  if (minutes < 24 * 60) return 4; // 6–24 hours
  if (minutes < 4 * 24 * 60) return 5; // 1–4 days
  if (minutes < 16 * 24 * 60) return 6; // 4–16 days
  return 7; // over 16 days
}

/**
 * Map total lifetime USD to Apple's lifetimeDollarsPurchased bucket (0-7).
 * 0 undeclared; 1 exactly 0; 2 0.01–49.99; 3 50–99.99;
 * 4 100–499.99; 5 500–999.99; 6 1000–1999.99; 7 >= 2000
 * @param {number|null|undefined} amountUsd
 * @returns {0|1|2|3|4|5|6|7}
 */
function mapLifetimeDollarsPurchased(amountUsd) {
  if (amountUsd == null || Number.isNaN(amountUsd)) return 0;
  if (amountUsd === 0) return 1;
  if (amountUsd < 50) return 2;
  if (amountUsd < 100) return 3;
  if (amountUsd < 500) return 4;
  if (amountUsd < 1000) return 5;
  if (amountUsd < 2000) return 6;
  return 7;
}

/**
 * Get the Firebase Auth user's creation time string (RFC 2822) or null.
 * @param {string} userId
 * @returns {Promise<string|null>}
 */
async function getUserCreationTime(userId) {
  const auth = getAuth();
  try {
    const userRecord = await auth.getUser(userId);
    return userRecord.metadata && userRecord.metadata.creationTime || null;
  } catch (error) {
    // If user not found or any error, return null
    return null;
  }
}

/**
 * Compute whole days since the provided creation time string.
 * @param {string|null} creationTime
 * @returns {number|null}
 */
function computeAccountAgeDays(creationTime) {
  if (!creationTime) return null;
  const createdAtMs = Date.parse(creationTime);
  if (Number.isNaN(createdAtMs)) return null;
  const diffMs = Date.now() - createdAtMs;
  return Math.floor(diffMs / (1000 * 60 * 60 * 24));
}

/**
 * Convenience helper to compute Apple's accountTenure bucket for a user.
 * @param {string} userId
 * @returns {Promise<number>} 0-7
 */
async function getAccountTenureForUser(userId) {
  const creationTime = await getUserCreationTime(userId);
  const accountAgeDays = computeAccountAgeDays(creationTime);
  return mapDaysToAccountTenure(accountAgeDays);
}

/**
 * Get lifetime purchase and refund data from RevenueCat or fallback to transaction data.
 * @param {string|null} revenueCatUserId - The RevenueCat customer ID
 * @param {string} currency - Transaction currency
 * @param {number} price - Transaction price
 * @param {string} revenueCatApiKey - RevenueCat API key
 * @returns {Promise<{lifetimePurchasesUsd: number, lifetimeRefundsUsd: number, lifetimeBucketVal: number, lifetimeRefundsBucketVal: number}>}
 */
async function getLifetimeValueData(
  revenueCatUserId,
  currency,
  price,
  revenueCatApiKey
) {
  let lifetimePurchasesUsd = 0;
  let lifetimeRefundsUsd = 0;

  if (revenueCatUserId) {
    try {
      const revenueCatService = new RevenueCatService(revenueCatApiKey);
      const lifetimeTotals = await revenueCatService.getCustomerLifetimeTotals(
        revenueCatUserId
      );
      lifetimePurchasesUsd = lifetimeTotals.lifetimePurchases;
      lifetimeRefundsUsd = lifetimeTotals.lifetimeRefunds;
    } catch (error) {
      console.warn(
        `Failed to fetch RevenueCat data for user ${revenueCatUserId}:`,
        error.message
      );
      // Fallback to current transaction data if RevenueCat fails
      lifetimePurchasesUsd =
        currency === "USD" && typeof price === "number" ? price / 100 : 0;
    }
  } else {
    // Fallback to current transaction data if no RevenueCat user ID
    lifetimePurchasesUsd =
      currency === "USD" && typeof price === "number" ? price / 100 : 0;
  }

  const lifetimeBucketVal = mapLifetimeDollarsPurchased(lifetimePurchasesUsd);
  const lifetimeRefundsBucketVal =
    mapLifetimeDollarsPurchased(lifetimeRefundsUsd);

  return {
    lifetimePurchasesUsd,
    lifetimeRefundsUsd,
    lifetimeBucketVal,
    lifetimeRefundsBucketVal,
  };
}

/**
 * Aggregate usage data from user consumption events in Firestore
 * @param {string} userId - The user ID
 * @returns {Promise<Object>} Aggregated usage data
 */
async function aggregateUsageData(userId) {
  try {
    // Get all consumption events for this user
    const eventsSnapshot = await db
      .collection("user_consumption")
      .doc(userId)
      .collection("events")
      .get();

    if (eventsSnapshot.empty) {
      console.log(`📊 No consumption events found for user: ${userId}`);
      return {
        totalAPICallsMade: 0,
        totalCostCents: 0,
        apiCallsCount: 0,
        externalAPICallsCount: 0,
        firebaseCallsCount: 0,
        apiCostCents: 0,
        externalAPICostCents: 0,
        firebaseCostCents: 0,
        featuresUsed: [],
        totalSessions: 0,
        featuresCreated: 0
      };
    }

    let apiCalls = 0;
    let externalAPICalls = 0;
    let firebaseCalls = 0;
    let apiCost = 0;
    let externalAPICost = 0;
    let firebaseCost = 0;
    const featuresSet = new Set();
    let sessionCount = 0;
    let featureCount = 0;

    eventsSnapshot.forEach((doc) => {
      const event = doc.data();

      switch (event.type) {
        case "api_call":
          if (event.successful) {
            apiCalls++;
            apiCost += event.cost_cents || 0;
          }
          break;
        case "external_api_call":
          if (event.successful) {
            externalAPICalls++;
            externalAPICost += event.cost_cents || 0;
          }
          break;
        case "firebase_call":
          if (event.successful) {
            firebaseCalls++;
            firebaseCost += event.cost_cents || 0;
          }
          break;
        case "feature_used":
          if (event.feature) {
            featuresSet.add(event.feature);
            // Track feature usage
            if (event.feature === "main_feature") {
              featureCount++;
            }
          }
          break;
        case "session_start":
          sessionCount++;
          break;
      }
    });

    const totalAPICalls = apiCalls + externalAPICalls + firebaseCalls;
    const totalCost = apiCost + externalAPICost + firebaseCost;

    const usageData = {
      totalAPICallsMade: totalAPICalls,
      totalCostCents: totalCost,
      apiCallsCount: apiCalls,
      externalAPICallsCount: externalAPICalls,
      firebaseCallsCount: firebaseCalls,
      apiCostCents: apiCost,
      externalAPICostCents: externalAPICost,
      firebaseCostCents: firebaseCost,
      featuresUsed: Array.from(featuresSet),
      totalSessions: sessionCount,
      featuresCreated: featureCount
    };

    console.log(`📊 Aggregated usage data for user ${userId}:`, usageData);
    return usageData;
  } catch (error) {
    console.error("❌ Error aggregating usage data:", error);
    // Return empty data on error rather than failing
    return {
      totalAPICallsMade: 0,
      totalCostCents: 0,
      apiCallsCount: 0,
      externalAPICallsCount: 0,
      firebaseCallsCount: 0,
      apiCostCents: 0,
      externalAPICostCents: 0,
      firebaseCostCents: 0,
      featuresUsed: [],
      totalSessions: 0,
      featuresCreated: 0
    };
  }
}

/**
 * Fetch consumption-related context for a given App Store transaction.
 * - Reads Firestore `transactions/{transactionId}` to obtain `userId`.
 * - Looks up the Firebase Auth user to get `creationTime`.
 * - Computes Apple's `accountTenure` bucket based on account age in days.
 *
 * @param {Object} transactionInfo - Transaction information
 * @param {string} revenueCatApiKey - RevenueCat API key
 * @returns {Promise<{transactionId:string,userId:string,userCreationDate:string,accountAgeDays:number,accountTenure:number}>}
 */
async function getConsumptionData(transactionInfo, revenueCatApiKey) {
  const {
    transactionId,
    purchaseDate,
    expiresDate,
    // productId, // Not used in this function
    price,
    currency,
  } = transactionInfo;

  // Load the transaction document
  const docRef = db.collection("transactions").doc(String(transactionId));
  const snap = await docRef.get();
  if (!snap.exists) {
    throw new Error(`Transaction not found: ${transactionId}`);
  }

  const data = snap.data() || {};
  const userId = data.userId;
  const usedSubscription = data.usedSubscription;
  const revenueCatUserId = data.revenueCatUserId;

  // Compute accountTenure using helpers
  const accountTenureVal = await getAccountTenureForUser(userId);
  const consumptionStatusVal = mapConsumptionStatus(
    purchaseDate,
    expiresDate,
    usedSubscription
  );
  const playTimeVal = mapPlayTimeMinutes((data.playTimeSeconds || 0) / 60);

  // Get lifetime purchase and refund data
  const lifetimeData = await getLifetimeValueData(
    revenueCatUserId,
    currency,
    price,
    revenueCatApiKey
  );
  const { lifetimeBucketVal, lifetimeRefundsBucketVal } = lifetimeData;

  // Aggregate usage data from consumption events
  const usageData = await aggregateUsageData(userId);

  const consumptionRequest = {
    accountTenure: accountTenureVal,
    appAccountToken: "",
    consumptionStatus: consumptionStatusVal,
    customerConsented: true,
    deliveryStatus: 0, // Deliverd
    lifetimeDollarsPurchased: lifetimeBucketVal,
    lifetimeDollarsRefunded: lifetimeRefundsBucketVal,
    platform: 1, // Apple platform
    playTime: playTimeVal,
    refundPreference: 2, // Prefer decline
    sampleContentProvided: true,
    userStatus: 1, // Active
    // Custom usage data for stronger evidence
    customData: usageData
  };

  return consumptionRequest;
}

module.exports = {
  getConsumptionData,
  getUserCreationTime,
  computeAccountAgeDays,
  mapDaysToAccountTenure,
  mapPlayTimeMinutes,
  getAccountTenureForUser,
  getLifetimeValueData,
  aggregateUsageData,
};
