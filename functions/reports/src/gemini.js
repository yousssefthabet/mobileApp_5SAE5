"use strict";

const { SYSTEM_PROMPT, buildUserText } = require("./prompt");

function dataUrl(base64) {
  let mime = "image/jpeg";
  if (base64.startsWith("iVBOR")) mime = "image/png";
  else if (base64.startsWith("UklGR")) mime = "image/webp";
  else if (base64.startsWith("R0lGOD")) mime = "image/gif";
  return mime;
}

/**
 * Analyzes municipal report with Google Gemini Multimodal Vision API.
 * Uses structured JSON output matching the exact application schema.
 */
async function analyzeWithGemini(apiKey, input) {
  const parts = [];

  const userText = buildUserText({ ...input, imageCount: input.images.length });

  const prompt = `${SYSTEM_PROMPT}

CRITICAL INSTRUCTION FOR MISMATCHED IMAGES:
Compare what is physically visible in the attached image(s) against the citizen's title and description.
- If the photo depicts a DIFFERENT problem than what the citizen reported (for example, the photo shows a street light or lamppost, but the report is about broken pavement, sidewalk, road damage, trash, or water leak; OR the photo shows a road, but the report is about lighting):
  * "recommended_status" MUST BE "REJECTED" (NEVER APPROVED or NEEDS_REVIEW)
  * "supports_reported_issue" MUST BE "contradicts"
  * "relevance" MUST BE "irrelevant"
  * "explanation" MUST explicitly tell the citizen: "The attached photo shows [what is actually visible, e.g. a streetlight], which does not match your report about [reported issue, e.g. broken pavement]. Please provide a photo of the actual issue."

CRITICAL: Return ONLY a valid JSON object matching this exact structure:
{
  "image_analysis": {
    "recommended_status": "APPROVED",
    "explanation": "Short polite explanation for the citizen",
    "relevance": "relevant",
    "image_quality": "clear",
    "supports_reported_issue": "supports",
    "content_concerns": [],
    "suspicious_signals": [],
    "per_image": [
      {
        "index": 0,
        "what_is_visible": "What is visible in this photo",
        "relevance": "relevant",
        "quality": "clear"
      }
    ]
  },
  "report": {
    "title": "${input.title.replace(/"/g, '\\"')}",
    "issue_type": "street_lighting",
    "problem_description": "${input.description.replace(/"/g, '\\"')}",
    "visual_observations": ["Observation 1", "Observation 2"],
    "citizen_reported_information": ["Reported fact 1"],
    "location_provided": "${(input.location && input.location.address) || 'Provided location'}",
    "urgency": "medium",
    "urgency_rationale": "Reason for urgency level",
    "responsible_department": "Name of responsible municipal department",
    "recommended_action": "Clear action step for workers",
    "limitations": ["Any limitations or inspection advice"]
  }
}

Valid issue_type values: street_lighting, road_damage, sidewalk_pedestrian, waste_sanitation, water_leak_sewage, drainage_flooding, traffic_signage_signals, parks_green_spaces, public_property_vandalism, electrical_hazard, building_structure, other.
Valid urgency values: low, medium, high, critical.
Valid recommended_status values: APPROVED, NEEDS_REVIEW, REJECTED.

Citizen submission to analyze:
${userText}`;

  parts.push({ text: prompt });

  for (const b64 of input.images) {
    const mime = dataUrl(b64);
    parts.push({
      inline_data: {
        mime_type: mime,
        data: b64,
      },
    });
  }

  // Try current fast Gemini vision models in order
  const models = ["gemini-2.5-flash", "gemini-1.5-flash", "gemini-1.5-pro"];
  let lastError = null;

  for (const model of models) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts }],
          generationConfig: {
            response_mime_type: "application/json",
            temperature: 0.1,
          },
        }),
      });

      if (!res.ok) {
        const errText = await res.text();
        throw new Error(`HTTP ${res.status}: ${errText}`);
      }

      const data = await res.json();
      const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!text) {
        throw new Error("Empty response from Gemini");
      }

      const parsed = JSON.parse(text);
      if (parsed && parsed.image_analysis) {
        const support = (parsed.image_analysis.supports_reported_issue || "").toLowerCase();
        const relevance = (parsed.image_analysis.relevance || "").toLowerCase();
        if (support === "contradicts" || relevance === "irrelevant") {
          parsed.image_analysis.recommended_status = "REJECTED";
        }
      }
      return { model, result: parsed };
    } catch (err) {
      lastError = err;
      console.warn(`[Gemini] Model ${model} call failed:`, err.message);
    }
  }

  throw lastError || new Error("All Gemini models failed");
}

module.exports = { analyzeWithGemini };
