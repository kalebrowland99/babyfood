# 🎯 Create No-Trial Prices (5 Minutes)

## Step 1: Create Main Price ($9.99 - NO TRIAL)

1. Go to [Stripe Dashboard](https://dashboard.stripe.com/test/products)
2. Find your "Thrifty Premium" product
3. Click **Add another price**

**Settings:**
```
Price: $9.99
Billing period: Recurring → Weekly (or Yearly - match your existing)
Trial period: LEAVE COMPLETELY BLANK ⚠️
```

4. Click **Add price**
5. **COPY THE PRICE ID** → Example: `price_1XxxxxxxxxxxxxxXXX`

---

## Step 2: Create Winback Price ($4.99 - NO TRIAL)

Same product, add another price:

**Settings:**
```
Price: $4.99
Billing period: Recurring → Weekly (or Yearly - match your existing)
Trial period: LEAVE COMPLETELY BLANK ⚠️
```

Click **Add price** and **COPY THE PRICE ID**

---

## Step 3: For OLD Pricing (Optional)

If you're still using old pricing tier, create these too:

**Old Main ($149 - NO TRIAL):**
```
Price: $149.00
Billing: Yearly
Trial: BLANK
```

**Old Winback ($79 - NO TRIAL):**
```
Price: $79.00
Billing: Yearly
Trial: BLANK
```

---

## Step 4: Give Me The Price IDs

Reply with:

```
New Main (no trial): price_xxxxx
New Winback (no trial): price_yyyyy
```

I'll hardcode them into the functions!

---

## ⚠️ Critical

Make sure **Trial period is COMPLETELY BLANK** when creating these prices. Don't set it to 0, just leave it empty/unconfigured.

---

**Time:** 5 minutes  
**Cost:** Free  
**Next:** I'll hardcode the IDs and deploy

