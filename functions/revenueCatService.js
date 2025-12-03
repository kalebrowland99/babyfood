/**
 * RevenueCat API Service
 * Handles authentication and customer data retrieval from RevenueCat REST API
 */
class RevenueCatService {
  constructor(apiKey) {
    this.apiKey = apiKey;
    this.projectId = "proj4fc1f100";
    this.baseURL = "https://api.revenuecat.com/v2";

    if (!this.apiKey) {
      throw new Error("RevenueCat API key is required");
    }
  }

  /**
   * Get customer's subscriptions
   * @param {string} customerId - The RevenueCat customer ID
   * @returns {Promise<Array>} Array of subscription objects
   */
  async getCustomerSubscriptions(customerId) {
    try {
      const url = `${this.baseURL}/projects/${this.projectId}/customers/${customerId}/subscriptions`;

      const response = await fetch(url, {
        method: "GET",
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          "Content-Type": "application/json",
        },
        signal: AbortSignal.timeout(10000), // 10 second timeout
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(
          `HTTP ${response.status}: ${errorData.message || response.statusText}`
        );
      }

      return await response.json();
    } catch (error) {
      console.error(
        `Error fetching subscriptions for customer ${customerId}:`,
        error.message
      );
      throw new Error(
        `Failed to fetch customer subscriptions: ${error.message}`
      );
    }
  }

  /**
   * Get customer's lifetime subscription totals in USD
   * @param {string} customerId - The RevenueCat customer ID
   * @returns {Promise<{lifetimePurchases: number, lifetimeRefunds: number}>}
   */
  async getCustomerLifetimeTotals(customerId) {
    try {
      const subscriptionsResponse = await this.getCustomerSubscriptions(
        customerId
      );
      // Extract the items array from the response
      const subscriptions = subscriptionsResponse.items || [];

      // Calculate total revenue from all subscriptions
      // Each subscription has total_revenue_in_usd.gross which is already in USD
      const lifetimePurchases = this.calculateTotalInUSD(subscriptions);
      const lifetimeRefunds = 0; // Subscriptions don't have refund status in this context

      return {
        lifetimePurchases,
        lifetimeRefunds,
      };
    } catch (error) {
      console.error(
        `Error calculating lifetime totals for customer ${customerId}:`,
        error
      );
      throw error;
    }
  }

  /**
   * Calculate total value in USD from an array of subscriptions
   * @param {Array} subscriptions - Array of subscription objects
   * @returns {number} Total value in USD
   */
  calculateTotalInUSD(subscriptions) {
    if (!Array.isArray(subscriptions)) {
      return 0;
    }

    return subscriptions.reduce((total, subscription) => {
      // Use the total_revenue_in_usd.gross field as the amount in USD
      const amount = subscription.total_revenue_in_usd && subscription.total_revenue_in_usd.gross || 0;
      return total + amount;
    }, 0);
  }
}

module.exports = {
  RevenueCatService,
};
