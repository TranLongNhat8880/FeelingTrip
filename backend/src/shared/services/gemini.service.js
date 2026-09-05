const env = require('../../config/env');

/**
 * Service to interact with Google Gemini API for AI Travel Planning
 */
const generateItineraryWithGemini = async ({ destination, durationDays, budget, preferences }) => {
  // Placeholder implementation for Google Gemini API call with structured JSON prompt
  // In production, use @google/genai or standard fetch/axios to https://generativelanguage.googleapis.com
  console.log(`[Gemini AI] Planning itinerary for ${destination}, ${durationDays} days`);

  return {
    destination,
    durationDays,
    budget,
    suggestedPlan: `AI Itinerary generated for ${destination}`,
  };
};

module.exports = {
  generateItineraryWithGemini,
};
