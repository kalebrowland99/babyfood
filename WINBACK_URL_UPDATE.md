# ✅ Winback URL Configuration Added

## Summary

Added support for a separate Stripe checkout URL specifically for winback offers. This allows you to use different Stripe products/prices for your main subscription vs winback offers.

---

## What Changed

### 1. New Remote Config Field
Added `winbackcheckouturl` to RemoteConfigManager:
- Loads from Firestore `app_config/paywall_config`
- Default value: `https://buy.stripe.com/YOUR_WINBACK_PAYMENT_LINK`
- Separate from main `stripecheckouturl`

### 2. Updated Winback Flow
The OneTimeOfferView now uses:
- `remoteConfig.winbackCheckoutUrl` (instead of calling Firebase function)
- Direct URL redirect (faster, simpler)
- Separate from main subscription URL

### 3. Benefits
✅ **Flexibility**: Use different Stripe products for winback offers  
✅ **Pricing Control**: Set different prices for winback vs regular  
✅ **A/B Testing**: Easy to test different winback prices  
✅ **Simplicity**: Direct URL, no Firebase function call needed  

---

## Firestore Configuration

In Firebase Console, add these fields to `app_config/paywall_config`:

```json
{
  "stripecheckouturl": "https://buy.stripe.com/8x2bJ14yl1kjfbL2Rt7Zu00",
  "winbackcheckouturl": "https://buy.stripe.com/YOUR_WINBACK_URL",
  "winbackdisclaimertext": "Free for 3 days, then $79.00 per year"
}
```

### Option 1: Same URL for Both (Simplest)
If you want to use the same price for both flows:
```json
{
  "stripecheckouturl": "https://buy.stripe.com/8x2bJ14yl1kjfbL2Rt7Zu00",
  "winbackcheckouturl": "https://buy.stripe.com/8x2bJ14yl1kjfbL2Rt7Zu00"
}
```

### Option 2: Different Prices (Recommended)
If you want a special winback price (e.g., $79/year for winback vs $149/year regular):

1. Create a second product in Stripe Dashboard
2. Set a different price (e.g., $79/year)
3. Create a payment link for that product
4. Use that URL for `winbackcheckouturl`

---

## Example Use Case

**Regular Subscription**: $149/year  
**Winback Offer**: $79/year (special discount)

```json
{
  "stripecheckouturl": "https://buy.stripe.com/regular_149_yearly",
  "winbackcheckouturl": "https://buy.stripe.com/winback_79_yearly",
  "stripedisclaimertext": "Free for 3 days, then $149/year",
  "winbackdisclaimertext": "Special offer! Free for 3 days, then only $79/year"
}
```

---

## Testing

1. Update Firestore with both URLs
2. Test the main subscription flow → should use `stripecheckouturl`
3. Cancel the subscription → winback should appear
4. Click winback button → should use `winbackcheckouturl`

---

## Migration Guide

If you already have `stripecheckouturl` configured:

1. Go to Firestore: `app_config/paywall_config`
2. Add new field: `winbackcheckouturl`
3. Set value to:
   - Same as `stripecheckouturl` (if same price)
   - Different Stripe URL (if different price)
4. Save

No code deployment needed - remote config loads automatically!

---

## Summary of All Stripe URLs

| Field | Used For | Example |
|-------|----------|---------|
| `stripecheckouturl` | Main subscription screen | $149/year regular price |
| `winbackcheckouturl` | Winback offer after cancel | $79/year special offer |

Both are required for full Stripe payment functionality.

---

**Updated**: November 6, 2025  
**Status**: Ready to configure ✅

