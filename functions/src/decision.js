"use strict";

/**
 * Combines the moderation results and the vision model's assessment into one
 * final status. The rules here are deterministic and always win over the
 * model, so a hallucinating model cannot reject a legitimate report or approve
 * a flagged one.
 */

const RANK = { APPROVED: 0, NEEDS_REVIEW: 1, REJECTED: 2 };

/**
 * Moderation categories that reject a photo outright. Everything else that
 * omni-moderation flags (violence, graphic content, hate, self-harm, illicit,
 * harassment...) goes to human review instead: a photo of a car crash,
 * an injured animal on the road or hateful graffiti can be a legitimate report.
 */
const IMAGE_REJECT_CATEGORIES = new Set(["sexual", "sexual/minors"]);
const TEXT_REJECT_CATEGORIES = new Set(["sexual/minors"]);

const CATEGORY_LABELS = {
  "sexual": "sexual content",
  "sexual/minors": "sexual content involving minors",
  "harassment": "harassment",
  "harassment/threatening": "threatening language",
  "hate": "hateful content",
  "hate/threatening": "threatening hateful content",
  "illicit": "illicit content",
  "illicit/violent": "violent illicit content",
  "self-harm": "self-harm",
  "self-harm/intent": "self-harm",
  "self-harm/instructions": "self-harm instructions",
  "violence": "violence",
  "violence/graphic": "graphic violence",
};

function flaggedCategories(result) {
  if (!result || !result.categories) return [];
  return Object.entries(result.categories)
    .filter(([, on]) => on === true)
    .map(([name]) => name);
}

/**
 * @param {{text: object|null, images: (object|null)[], errors: string[]}} moderation
 *   omni-moderation result objects (results[0]) for the text and each image.
 */
function moderationVerdict(moderation) {
  const reasons = [];
  const categories = [];
  let status = "APPROVED";

  const raise = (s) => {
    if (RANK[s] > RANK[status]) status = s;
  };

  (moderation.images || []).forEach((res, i) => {
    for (const cat of flaggedCategories(res)) {
      categories.push(`photo ${i + 1}: ${cat}`);
      if (IMAGE_REJECT_CATEGORIES.has(cat)) {
        raise("REJECTED");
        reasons.push(`Photo ${i + 1} appears to contain ${CATEGORY_LABELS[cat] || cat}, which is not allowed.`);
      } else {
        raise("NEEDS_REVIEW");
        reasons.push(`Photo ${i + 1} may contain ${CATEGORY_LABELS[cat] || cat}; a moderator will check it.`);
      }
    }
  });

  for (const cat of flaggedCategories(moderation.text)) {
    categories.push(`text: ${cat}`);
    if (TEXT_REJECT_CATEGORIES.has(cat)) {
      raise("REJECTED");
      reasons.push(`The description contains ${CATEGORY_LABELS[cat] || cat}, which is not allowed.`);
    } else {
      raise("NEEDS_REVIEW");
      reasons.push(`The description may contain ${CATEGORY_LABELS[cat] || cat}; a moderator will check it.`);
    }
  }

  if ((moderation.errors || []).length > 0) {
    raise("NEEDS_REVIEW");
    reasons.push("The automatic safety check could not be completed; a moderator will check the photos.");
  }

  return { status, reasons, categories };
}

/**
 * Applies guardrails to the model's own recommendation.
 * @param {object|null} analysis image_analysis object from the vision model.
 */
function visionVerdict(analysis) {
  if (!analysis) {
    return {
      status: "NEEDS_REVIEW",
      reasons: ["The automatic photo analysis could not be completed; a moderator will review the report."],
    };
  }

  const reasons = [];
  let status = analysis.recommended_status;
  if (!(status in RANK)) status = "NEEDS_REVIEW";

  const concerns = analysis.content_concerns || [];
  const suspicious = analysis.suspicious_signals || [];
  const irrelevant = analysis.relevance === "irrelevant";

  // The model may only reject for unrelated photos or prohibited content.
  // Anything else it wants to reject goes to a human instead.
  if (status === "REJECTED" && !irrelevant && concerns.length === 0) {
    status = "NEEDS_REVIEW";
  }

  // The model may not approve something with open questions.
  if (status === "APPROVED") {
    const doubts = [];
    if (analysis.relevance !== "relevant") doubts.push("the photos may not match the reported problem");
    if (analysis.image_quality !== "clear") doubts.push(`photo quality: ${String(analysis.image_quality).replace(/_/g, " ")}`);
    if (analysis.supports_reported_issue === "contradicts") doubts.push("the photos seem to contradict the description");
    if (concerns.length) doubts.push("possible content concerns");
    if (suspicious.length) doubts.push("unusual signals in the submission");
    if (doubts.length) {
      status = "NEEDS_REVIEW";
      reasons.push(`A moderator will check this report (${doubts.join("; ")}).`);
    }
  }

  if (status !== "APPROVED" && analysis.explanation) {
    reasons.unshift(analysis.explanation);
  }

  return { status, reasons };
}

/** Final status = the stricter of the two verdicts. */
function combine(moderation, analysis) {
  const mod = moderationVerdict(moderation);
  const vis = visionVerdict(analysis);
  const status = RANK[mod.status] >= RANK[vis.status] ? mod.status : vis.status;

  // Show the reasons of whatever caused the final status first.
  const ordered =
    RANK[mod.status] >= RANK[vis.status]
      ? [...mod.reasons, ...vis.reasons]
      : [...vis.reasons, ...mod.reasons];
  const reasons = [...new Set(ordered.filter(Boolean))];

  let explanation;
  if (status === "APPROVED") {
    explanation = (analysis && analysis.explanation) || "The photos match the reported problem.";
  } else {
    explanation = reasons.join(" ");
  }

  return {
    status,
    explanation,
    reasons,
    moderationCategories: mod.categories,
  };
}

module.exports = { combine, moderationVerdict, visionVerdict, RANK };
