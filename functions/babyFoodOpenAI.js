/**
 * Baby Food app — OpenAI proxy (key stored in Secret Manager: OPENAI_API_KEY).
 *
 * Deploy:
 *   firebase use baby-food-834f7   # or your project
 *   firebase functions:secrets:set OPENAI_API_KEY
 *   firebase deploy --only functions:babyFoodOpenAI
 *
 * Do NOT paste API keys into this file or into git.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const openaiApiKeySecret = defineSecret("OPENAI_API_KEY");

const CHAT_SYSTEM = `You are a warm, knowledgeable baby nutrition expert and chef. You help mothers confidently introduce solid foods to their babies.

Your expertise includes:
- Age-appropriate food introductions:
  • 4–6 months: smooth single-ingredient purees (sweet potato, peas, banana)
  • 6–9 months: mashed/lumpy foods, soft combinations
  • 9–12 months: soft finger foods, bite-sized pieces
  • 12+ months: most family foods in appropriate textures
- Safe textures for each developmental stage
- Allergen introduction (eggs, peanuts, dairy, tree nuts, wheat, soy, fish, shellfish) — introduce one at a time, wait 3–5 days between new allergens
- Nutritional priorities: iron, zinc, vitamin D, B12, calcium, omega-3s
- Baby-led weaning vs spoon feeding approaches
- Foods to AVOID under 12 months: honey, added salt, added sugar, cow's milk as main drink, whole nuts, hard raw vegetables, popcorn, large chunks
- Batch cooking and leftover tips
- Signs of food allergies: hives, vomiting, swelling — always refer to pediatrician for concerns

Tone: warm, encouraging, and practical. Keep responses concise (2–4 short paragraphs or bullet points). Format recipes clearly with an ingredients list and numbered steps. Always end allergy/safety advice with "When in doubt, check with your pediatrician. 👨‍⚕️"`;

function textureGuideForAge(ageStage) {
  switch (ageStage) {
  case "4–6 months":
    return "Smooth, single-ingredient purees only (no chunks, no combos).";
  case "6–9 months":
    return "Mashed and lightly lumpy foods, simple 2-ingredient combos.";
  case "9–12 months":
    return "Soft finger foods and bite-sized pieces, more complex flavours.";
  default:
    return "Soft family foods in baby-appropriate portions, varied textures.";
  }
}

function buildMealPlanPrompt(ageStage, restrictions) {
  const restrictionText = !restrictions || restrictions.length === 0 ?
    "No dietary restrictions." :
    `Dietary restrictions: ${restrictions.join(", ")}.`;
  const textureGuide = textureGuideForAge(ageStage);
  return `Generate a 7-day meal plan for a ${ageStage} baby. ${restrictionText}
Texture guide: ${textureGuide}

Return ONLY valid JSON, no markdown, no explanation:
{
  "days": [
    { "day": "Monday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." },
    { "day": "Tuesday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." },
    { "day": "Wednesday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." },
    { "day": "Thursday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." },
    { "day": "Friday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." },
    { "day": "Saturday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." },
    { "day": "Sunday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." }
  ]
}

Rules:
- Each meal: max 7 words, descriptive and appetising
- Never include honey, added salt, added sugar, whole nuts, or raw hard vegetables
- Vary proteins, colours, and food groups across the week
- Include iron-rich foods at least 3 times per week
`;
}

function buildShoppingListPrompt(planText) {
  const safe = String(planText || "").slice(0, 20000);
  return `Based on this 7-day baby meal plan:
${safe}

Generate a consolidated shopping list with quantities.
Return ONLY valid JSON, no markdown:
{
  "items": [
    "Sweet potatoes (4 medium)",
    "Avocado (3)",
    "Rolled oats (1 cup)"
  ]
}

Rules:
- Group by category: Produce first, then Grains, Proteins, Dairy/Alternatives, Pantry
- Consolidate duplicates across the week
- 15–25 items maximum
- Include realistic quantities for a baby (small amounts)
`;
}

exports.babyFoodOpenAI = onCall(
    {
      region: "us-central1",
      maxInstances: 20,
      enforceAppCheck: false,
      secrets: [openaiApiKeySecret],
      memory: "512MiB",
      timeoutSeconds: 120,
    },
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError("unauthenticated", "Sign in to use AI features.");
      }

      const apiKey = openaiApiKeySecret.value();
      if (!apiKey || typeof apiKey !== "string") {
        console.error("OPENAI_API_KEY secret is not set");
        throw new HttpsError("failed-precondition", "Server is missing OpenAI configuration.");
      }

      const data = request.data || {};
      const kind = data.kind;
      let messages;
      let max_tokens = 600;
      let temperature = 0.7;
      const model = "gpt-4o";

      if (kind === "chat") {
        const raw = data.messages;
        if (!Array.isArray(raw) || raw.length === 0) {
          throw new HttpsError("invalid-argument", "messages array is required");
        }
        const filtered = raw
            .filter((m) => m && (m.role === "user" || m.role === "assistant") && typeof m.content === "string")
            .slice(-30)
            .map((m) => ({ role: m.role, content: m.content.slice(0, 12000) }));
        if (filtered.length === 0) {
          throw new HttpsError("invalid-argument", "No valid chat messages");
        }
        messages = [{ role: "system", content: CHAT_SYSTEM }, ...filtered];
        max_tokens = Math.min(Math.max(Number(data.max_tokens) || 600, 100), 800);
        temperature = typeof data.temperature === "number" ?
          Math.min(Math.max(data.temperature, 0), 1) : 0.7;
      } else if (kind === "meal_plan") {
        const ageStage = typeof data.ageStage === "string" ? data.ageStage.trim() : "";
        const restrictions = Array.isArray(data.restrictions) ? data.restrictions.filter((x) => typeof x === "string") : [];
        if (!ageStage || ageStage.length > 80) {
          throw new HttpsError("invalid-argument", "ageStage is required");
        }
        const prompt = buildMealPlanPrompt(ageStage, restrictions);
        messages = [{ role: "user", content: prompt }];
        max_tokens = 800;
        temperature = 0.7;
      } else if (kind === "shopping_list") {
        const planText = typeof data.planText === "string" ? data.planText : "";
        if (!planText.trim()) {
          throw new HttpsError("invalid-argument", "planText is required");
        }
        const prompt = buildShoppingListPrompt(planText);
        messages = [{ role: "user", content: prompt }];
        max_tokens = 400;
        temperature = 0.3;
      } else {
        throw new HttpsError("invalid-argument", "kind must be chat, meal_plan, or shopping_list");
      }

      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ model, messages, max_tokens, temperature }),
      });

      const rawText = await res.text();
      if (!res.ok) {
        console.error("OpenAI HTTP error", res.status, rawText.slice(0, 500));
        throw new HttpsError("internal", "OpenAI request failed");
      }

      let json;
      try {
        json = JSON.parse(rawText);
      } catch (e) {
        console.error("OpenAI invalid JSON", e);
        throw new HttpsError("internal", "Invalid OpenAI response");
      }

      const content = json?.choices?.[0]?.message?.content;
      if (!content || typeof content !== "string") {
        throw new HttpsError("internal", "Unexpected OpenAI response shape");
      }

      return { content: content.trim() };
    },
);
