import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getCorsHeaders } from "../_shared/cors.ts";
import { fetchPlantKnowledge } from "../_shared/plant-knowledge.ts";
import { validateAuthOrB2BApiKey } from "../_shared/b2b-auth.ts";

const PROMPT_VERSION = "1.2.0";
const AI_MODEL_NAME = "gemini-2.0-flash";

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

type Recommendation = {
  recommendation_code: string;
  recommendation_localized: string;
  recommendation_details_localized?: string | null;
  priority?: "high" | "medium" | "low";
  expected_followup_window_hours?: number;
  risk_level?: "low" | "medium" | "high";
  randomization_allowed?: boolean;
};

type CommerceLink = {
  product_type: string;
  search_query: string;
  affiliate_url_template: string;
};

const DEFAULT_AFFILIATE_TEMPLATE = "https://www.amazon.in/s?k={query}";
const ALLOWED_AFFILIATE_HOSTS = new Set([
  "www.amazon.in",
  "amazon.in",
  "www.amazon.com",
  "amazon.com",
]);

const SAFE_RECOMMENDATION_CODES = new Set([
  "reduce_watering_frequency",
  "increase_airflow",
  "move_to_brighter_indirect_light",
  "isolate_plant",
  "rinse_leaves_for_dust",
  "improve_drainage",
  "check_for_pests",
  "remove_damaged_leaves",
  "rotate_plant_weekly",
  "monitor_soil_moisture",
  "adjust_humidity",
]);

function toCanonicalCode(input: string): string {
  const normalized = input
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\s_]/g, "")
    .replace(/\s+/g, "_")
    .replace(/_+/g, "_");

  if (!normalized) return "monitor_soil_moisture";
  if (SAFE_RECOMMENDATION_CODES.has(normalized)) return normalized;

  if (normalized.includes("water")) return "reduce_watering_frequency";
  if (normalized.includes("air")) return "increase_airflow";
  if (normalized.includes("light")) return "move_to_brighter_indirect_light";
  if (normalized.includes("isolate")) return "isolate_plant";
  if (normalized.includes("dust") || normalized.includes("rinse")) {
    return "rinse_leaves_for_dust";
  }
  if (normalized.includes("drain")) return "improve_drainage";
  if (normalized.includes("pest")) return "check_for_pests";
  if (normalized.includes("remove") || normalized.includes("prune")) {
    return "remove_damaged_leaves";
  }
  if (normalized.includes("rotate")) return "rotate_plant_weekly";
  if (normalized.includes("humidity")) return "adjust_humidity";

  return "monitor_soil_moisture";
}

function toSnakeCase(input: string, fallback: string): string {
  const normalized = input
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\s_]/g, "")
    .replace(/\s+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "");
  return normalized || fallback;
}

function confidenceBand(score: number): "low" | "medium" | "high" {
  if (score < 0.4) return "low";
  if (score < 0.75) return "medium";
  return "high";
}

function sanitizeAffiliateTemplate(value: string | null | undefined): string {
  const raw = (value ?? "").trim();
  if (!raw.includes("{query}")) return DEFAULT_AFFILIATE_TEMPLATE;

  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch (_error) {
    return DEFAULT_AFFILIATE_TEMPLATE;
  }

  if (parsed.protocol !== "https:") return DEFAULT_AFFILIATE_TEMPLATE;
  if (!ALLOWED_AFFILIATE_HOSTS.has(parsed.hostname)) return DEFAULT_AFFILIATE_TEMPLATE;

  return raw;
}

function buildDiagnosisPrompt(params: {
  plant: Record<string, unknown>;
  scan: Record<string, unknown>;
  locale: string;
  imageQuality: number | null;
  plantKnowledgeSummary: string;
}): string {
  const { plant, scan, locale, imageQuality, plantKnowledgeSummary } = params;

  const qualityWarning =
    imageQuality !== null && imageQuality < 0.4
      ? "\nNOTE: The image quality is LOW. Reduce confidence if uncertain and explain why."
      : "";

  return `You are an expert plant pathologist and horticulturist. Analyze the provided plant image and return a strict JSON result.\n\n## Plant Profile\n- Nickname: ${plant.nickname ?? "Unknown"}\n- Species (scientific): ${plant.species_scientific ?? "Unknown"}\n- Species (common): ${plant.species_common ?? "Unknown"}\n- Environment: ${JSON.stringify(plant.environment_profile ?? {})}\n\n## External Plant Knowledge (rules/API)\n${plantKnowledgeSummary}\n\n## Environmental Telemetry\n- Temperature: ${scan.temp_c !== null ? `${scan.temp_c}C` : "unavailable"}\n- Humidity: ${scan.humidity_pct !== null ? `${scan.humidity_pct}%` : "unavailable"}\n- VPD: ${scan.vpd_kpa !== null ? `${scan.vpd_kpa} kPa` : "unavailable"}\n- Light (lux): ${scan.lux_reading !== null ? scan.lux_reading : "unavailable"}\n- AQI: ${scan.aqi !== null ? scan.aqi : "unavailable"}\n- Solar Radiation: ${scan.solar_radiation_wm2 !== null ? `${scan.solar_radiation_wm2} W/m2` : "unavailable"}\n${qualityWarning}\n\n## Instructions\n1. Diagnose probable plant issue(s) from image + telemetry + external plant knowledge.\n2. Write diagnosis and treatment in ${locale}.\n3. diagnosis_code must always be canonical English snake_case.\n4. Return 1 to 3 practical recommendations with canonical recommendation_code in English snake_case and localized text in ${locale}.\n5. Return treatment_plan.commerce_links with actionable product search intents.\n6. Each commerce_links item must include product_type, search_query, and affiliate_url_template with {query} placeholder.\n7. Keep risk_level low/medium/high and randomization_allowed false by default.\n8. Avoid contradictory recommendations in the same response.\n9. If uncertain, lower confidence and include uncertainty_reason.\n10. Output JSON ONLY.\n\n## Required JSON\n{\n  "diagnosis_code": "string",\n  "diagnosis_localized": "string",\n  "treatment_localized": "string",\n  "treatment_plan": {\n    "commerce_links": [\n      {\n        "product_type": "string",\n        "search_query": "string",\n        "affiliate_url_template": "https://www.amazon.in/s?k={query}"\n      }\n    ]\n  },\n  "health_score": 0,\n  "visual_symptoms": ["string"],\n  "confidence": 0.0,\n  "uncertainty_reason": null,\n  "recommendations": [\n    {\n      "recommendation_code": "string",\n      "recommendation_localized": "string",\n      "recommendation_details_localized": "string",\n      "priority": "high|medium|low",\n      "expected_followup_window_hours": 72,\n      "risk_level": "low|medium|high",\n      "randomization_allowed": false\n    }\n  ]\n}`;
}

function parseModelJson(responseText: string): Record<string, unknown> {
  const jsonMatch = responseText.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error("No JSON object found in model response");
  return JSON.parse(jsonMatch[0]);
}

function normalizeRecommendations(raw: unknown): Recommendation[] {
  if (!Array.isArray(raw)) return [];
  const seen = new Set<string>();

  return raw
    .map((item) => {
      if (!item || typeof item !== "object") return null;
      const rec = item as Record<string, unknown>;

      const localized = String(rec.recommendation_localized ?? "").trim();
      if (!localized) return null;

      const priorityRaw = String(rec.priority ?? "medium").toLowerCase();
      const riskRaw = String(rec.risk_level ?? "low").toLowerCase();
      const priority: Recommendation["priority"] =
        priorityRaw === "high" || priorityRaw === "low" ? priorityRaw : "medium";
      const risk_level: Recommendation["risk_level"] =
        riskRaw === "medium" || riskRaw === "high" ? riskRaw : "low";

      const expected = Number(rec.expected_followup_window_hours ?? 72);
      const expected_followup_window_hours =
        Number.isFinite(expected) && expected > 0 ? Math.round(expected) : 72;

      const recommendation_code = toCanonicalCode(
        String(rec.recommendation_code ?? localized),
      );
      if (seen.has(recommendation_code)) return null;
      seen.add(recommendation_code);

      const randomizationAllowed = Boolean(rec.randomization_allowed ?? false) &&
        risk_level === "low";

      return {
        recommendation_code,
        recommendation_localized: localized,
        recommendation_details_localized:
          rec.recommendation_details_localized != null
            ? String(rec.recommendation_details_localized)
            : null,
        priority,
        expected_followup_window_hours,
        risk_level,
        randomization_allowed: randomizationAllowed,
      } as Recommendation;
    })
    .filter((r): r is Recommendation => r !== null)
    .slice(0, 3);
}

function normalizeCommerceLinks(raw: unknown): CommerceLink[] {
  if (!Array.isArray(raw)) return [];
  const seenQueries = new Set<string>();

  return raw
    .map((item) => {
      if (!item || typeof item !== "object") return null;
      const row = item as Record<string, unknown>;
      const product_type = String(row.product_type ?? "").trim();
      const search_query = String(row.search_query ?? "").trim();
      const canonicalQuery = search_query.toLowerCase();
      if (seenQueries.has(canonicalQuery)) return null;
      seenQueries.add(canonicalQuery);
      const affiliate_url_template = sanitizeAffiliateTemplate(
        String(row.affiliate_url_template ?? DEFAULT_AFFILIATE_TEMPLATE),
      );
      if (!product_type || !search_query) return null;
      return { product_type, search_query, affiliate_url_template } as CommerceLink;
    })
    .filter((row): row is CommerceLink => row !== null)
    .slice(0, 4);
}

serve(async (req: Request) => {
  const corsHeaders = getCorsHeaders(req.headers.get("Origin"));

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
  const serviceClient = createClient(supabaseUrl, supabaseServiceKey);

  const authResult = await validateAuthOrB2BApiKey(req, corsHeaders, serviceClient);
  if (authResult instanceof Response) return authResult;

  let scanId: string | null = null;

  try {
    const body = await req.json();
    scanId = body.scan_id;
    if (!scanId) {
      return new Response(JSON.stringify({ error: "Missing scan_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!geminiApiKey) throw new Error("GEMINI_API_KEY not configured");

    await serviceClient
      .from("scan_jobs")
      .update({ status: "running", started_at: new Date().toISOString() })
      .eq("scan_id", scanId)
      .eq("job_type", "diagnose_ai");

    await serviceClient
      .from("scans")
      .update({ processing_status: "diagnosing" })
      .eq("id", scanId);

    const { data: scan, error: scanError } = await serviceClient
      .from("scans")
      .select("*, plants(*)")
      .eq("id", scanId)
      .single();

    if (scanError || !scan) throw new Error(`Scan not found: ${scanId}`);

    const { data: userProfile } = await serviceClient
      .from("users")
      .select("locale_code")
      .eq("id", scan.user_id)
      .single();

    const locale = userProfile?.locale_code ?? "en";
    const speciesHint = String(
      scan.plants?.species_scientific ??
        scan.plants?.species_common ??
        "",
    );
    const plantKnowledge = await fetchPlantKnowledge(speciesHint);

    const { data: signedUrlData, error: signedUrlError } = await serviceClient.storage
      .from("plant-scans")
      .createSignedUrl(scan.image_path, 300);

    if (signedUrlError || !signedUrlData?.signedUrl) {
      throw new Error("Failed to create signed URL for image");
    }

    const imageResponse = await fetch(signedUrlData.signedUrl);
    if (!imageResponse.ok) throw new Error("Failed to download image");

    const imageBytes = new Uint8Array(await imageResponse.arrayBuffer());
    const base64Image = btoa(String.fromCharCode(...imageBytes));

    const prompt = buildDiagnosisPrompt({
      plant: scan.plants ?? {},
      scan,
      locale,
      imageQuality: scan.image_quality_score,
      plantKnowledgeSummary: plantKnowledge.summary,
    });

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${AI_MODEL_NAME}:generateContent?key=${geminiApiKey}`;

    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt },
              { inline_data: { mime_type: "image/jpeg", data: base64Image } },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.3,
          topP: 0.8,
          maxOutputTokens: 2048,
          responseMimeType: "application/json",
        },
      }),
    });

    if (!geminiResponse.ok) {
      throw new Error(`Gemini API error: ${geminiResponse.status} ${await geminiResponse.text()}`);
    }

    const geminiData = await geminiResponse.json();
    const responseText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    let diagnosis: Record<string, unknown>;
    try {
      diagnosis = parseModelJson(responseText);
    } catch (_error) {
      diagnosis = {
        diagnosis_code: "parse_error",
        diagnosis_localized: "Unable to parse AI response",
        treatment_localized: "Please try scanning again",
        treatment_plan: { commerce_links: [] },
        health_score: 50,
        visual_symptoms: [],
        confidence: 0,
        uncertainty_reason: "AI response could not be parsed",
        recommendations: [],
      };
    }

    const healthScore = Math.max(0, Math.min(100, Math.round(Number(diagnosis.health_score) || 50)));
    const confidence = Math.max(0, Math.min(1, Number(diagnosis.confidence) || 0));
    const normalizedDiagnosisCode = toSnakeCase(
      String(diagnosis.diagnosis_code ?? "unknown"),
      "unknown",
    );
    const uncertaintyReason = diagnosis.uncertainty_reason != null
      ? String(diagnosis.uncertainty_reason)
      : null;
    const modelVersion = geminiData.modelVersion ?? AI_MODEL_NAME;

    const recommendations = normalizeRecommendations(diagnosis.recommendations);
    const commerceLinks = normalizeCommerceLinks(
      (diagnosis.treatment_plan as Record<string, unknown> | undefined)
        ?.commerce_links,
    );
    const band = confidenceBand(confidence);
    const effectiveUncertaintyReason = band === "low" && (uncertaintyReason == null || uncertaintyReason.isEmpty)
      ? "Low confidence due to limited visual or telemetry certainty."
      : uncertaintyReason;

    const { error: updateError } = await serviceClient
      .from("scans")
      .update({
        ai_model_name: AI_MODEL_NAME,
        ai_model_version: modelVersion,
        prompt_version: PROMPT_VERSION,
        diagnosis_confidence: confidence,
        health_score: healthScore,
        diagnosis_code: normalizedDiagnosisCode,
        diagnosis_localized: String(diagnosis.diagnosis_localized ?? ""),
        treatment_localized: String(diagnosis.treatment_localized ?? ""),
        visual_symptoms: Array.isArray(diagnosis.visual_symptoms)
          ? diagnosis.visual_symptoms.map(String)
          : [],
        ai_diagnosis_raw: {
          ...diagnosis,
          knowledge_source: plantKnowledge.provider,
          knowledge_summary: plantKnowledge.summary,
          treatment_plan: {
            ...((diagnosis.treatment_plan as Record<string, unknown> | undefined) ?? {}),
            commerce_links: commerceLinks,
          },
          confidence_band: band,
          uncertainty_reason: effectiveUncertaintyReason,
          guardrails_applied: {
            normalized_diagnosis_code: true,
            deduped_recommendations: true,
            sanitized_commerce_links: true,
            risk_based_randomization_blocked: true,
          },
        },
        processing_status: "completed",
        processing_error: null,
      })
      .eq("id", scanId);

    if (updateError) throw updateError;

    let recommendationsCreated = 0;

    if (recommendations.length > 0) {
      const now = new Date();
      const { data: existingInterventions, error: existingInterventionsError } =
        await serviceClient
          .from("intervention_recommendations")
          .select("id, recommendation_code, user_id, plant_id, followup_due_at_utc")
          .eq("scan_id", scanId);

      if (existingInterventionsError) throw existingInterventionsError;

      const existingByCode = new Map(
        (existingInterventions ?? []).map((row) => [row.recommendation_code, row]),
      );

      const interventionsToInsert = recommendations
        .filter((rec) => !existingByCode.has(rec.recommendation_code))
        .map((rec) => {
          const followupDue = new Date(
            now.getTime() + (rec.expected_followup_window_hours ?? 72) * 60 * 60 * 1000,
          );
          return {
            scan_id: scanId,
            user_id: scan.user_id,
            plant_id: scan.plant_id,
            recommendation_code: rec.recommendation_code,
            recommendation_localized: rec.recommendation_localized,
            recommendation_details_localized: rec.recommendation_details_localized ?? null,
            priority: rec.priority ?? "medium",
            expected_followup_window_hours: rec.expected_followup_window_hours ?? 72,
            followup_due_at_utc: followupDue.toISOString(),
            followup_status: "pending",
            source: plantKnowledge.provider === "perenual" ? "hybrid" : "gemini",
            ai_model_name: AI_MODEL_NAME,
            ai_model_version: modelVersion,
            prompt_version: PROMPT_VERSION,
            is_randomized: false,
            randomization_allowed: rec.randomization_allowed ?? false,
            risk_level: rec.risk_level ?? "low",
          };
        });

      let insertedInterventions:
        | Array<{ id: string; user_id: string; plant_id: string; followup_due_at_utc: string }>
        | null = null;

      if (interventionsToInsert.length > 0) {
        const { data, error: interventionsError } = await serviceClient
          .from("intervention_recommendations")
          .insert(interventionsToInsert)
          .select("id, user_id, plant_id, followup_due_at_utc");

        if (interventionsError) throw interventionsError;
        insertedInterventions = data;
        recommendationsCreated = data?.length ?? 0;
      }

      const allInterventionsForMission = [
        ...((existingInterventions ?? []).map((row) => ({
          id: row.id,
          user_id: row.user_id,
          plant_id: row.plant_id,
          followup_due_at_utc: row.followup_due_at_utc,
        })) ?? []),
        ...((insertedInterventions ?? []) ?? []),
      ];

      if (allInterventionsForMission.length > 0) {
        const interventionIds = allInterventionsForMission.map((row) => row.id);
        const { data: existingMissions, error: existingMissionsError } = await serviceClient
          .from("followup_missions")
          .select("intervention_id")
          .in("intervention_id", interventionIds)
          .eq("mission_type", "log_outcome");

        if (existingMissionsError) throw existingMissionsError;

        const existingMissionInterventionIds = new Set(
          (existingMissions ?? []).map((row) => row.intervention_id),
        );

        const missions = allInterventionsForMission
          .filter((row) => !existingMissionInterventionIds.has(row.id))
          .map((row) => ({
            user_id: row.user_id,
            plant_id: row.plant_id,
            intervention_id: row.id,
            mission_type: "log_outcome",
            due_at_utc: row.followup_due_at_utc,
            status: "pending",
            notification_scheduled: false,
          }));

        if (missions.length > 0) {
          const { error: missionsError } = await serviceClient
            .from("followup_missions")
            .insert(missions);

          if (missionsError) throw missionsError;
        }
      }
    }

    await serviceClient
      .from("scan_jobs")
      .update({ status: "succeeded", finished_at: new Date().toISOString() })
      .eq("scan_id", scanId)
      .eq("job_type", "diagnose_ai");

    return new Response(
      JSON.stringify({
        status: "completed",
        diagnosis: {
          diagnosis_code: diagnosis.diagnosis_code,
          health_score: healthScore,
          confidence,
        },
        knowledge_source: plantKnowledge.provider,
        auth_mode: authResult.mode,
        recommendations_created: recommendationsCreated,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("diagnose-ai error:", error);

    if (scanId) {
      await serviceClient
        .from("scans")
        .update({
          processing_status: "failed",
          processing_error: errorMessage(error) || "Unknown error",
        })
        .eq("id", scanId);

      await serviceClient
        .from("scan_jobs")
        .update({
          status: "failed",
          finished_at: new Date().toISOString(),
          error_message: errorMessage(error) || "Unknown error",
        })
        .eq("scan_id", scanId)
        .eq("job_type", "diagnose_ai");
    }

    return new Response(
      JSON.stringify({ error: errorMessage(error) || "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
