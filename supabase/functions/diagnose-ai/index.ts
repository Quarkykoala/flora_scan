import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getCorsHeaders } from "../_shared/cors.ts";

const PROMPT_VERSION = "1.0.0";
const AI_MODEL_NAME = "gemini-2.0-flash";

function buildDiagnosisPrompt(params: {
  plant: Record<string, unknown>;
  scan: Record<string, unknown>;
  locale: string;
  imageQuality: number | null;
}): string {
  const { plant, scan, locale, imageQuality } = params;

  const qualityWarning =
    imageQuality !== null && imageQuality < 0.4
      ? "\n⚠️ NOTE: The image quality is LOW. Factor this into your confidence assessment and mention it if relevant."
      : "";

  return `You are an expert plant pathologist and horticulturist. Analyze the provided plant image and return a health diagnosis.

## Plant Profile
- Nickname: ${plant.nickname ?? "Unknown"}
- Species (scientific): ${plant.species_scientific ?? "Unknown"}
- Species (common): ${plant.species_common ?? "Unknown"}
- Environment: ${JSON.stringify(plant.environment_profile ?? {})}

## Environmental Telemetry
- Temperature: ${scan.temp_c !== null ? `${scan.temp_c}°C` : "unavailable"}
- Humidity: ${scan.humidity_pct !== null ? `${scan.humidity_pct}%` : "unavailable"}
- VPD: ${scan.vpd_kpa !== null ? `${scan.vpd_kpa} kPa` : "unavailable"}
- Light (lux): ${scan.lux_reading !== null ? scan.lux_reading : "unavailable"}
- AQI: ${scan.aqi !== null ? scan.aqi : "unavailable"}
- Solar Radiation: ${scan.solar_radiation_wm2 !== null ? `${scan.solar_radiation_wm2} W/m²` : "unavailable"}
${qualityWarning}

## Instructions
1. Analyze the plant image for visible health issues, diseases, nutrient deficiencies, or pest damage.
2. Consider the environmental telemetry when forming your diagnosis.
3. Provide your response in ${locale} language.
4. Use a canonical English diagnosis_code regardless of locale.
5. If you are uncertain, say so. Prefer uncertainty over hallucination.
6. Return ONLY valid JSON with no additional text, markdown, or explanation.

## Required JSON Response Format
{
  "diagnosis_code": "string (canonical English code, e.g. 'healthy', 'nitrogen_deficiency', 'powdery_mildew', 'overwatering', 'root_rot', 'pest_aphids', 'sunburn', 'unknown')",
  "diagnosis_localized": "string (diagnosis description in ${locale})",
  "treatment_localized": "string (treatment recommendation in ${locale})",
  "health_score": number (0-100, where 100 is perfectly healthy),
  "visual_symptoms": ["array of observed symptoms in ${locale}"],
  "confidence": number (0-1, your confidence in this diagnosis),
  "uncertainty_reason": "string or null (explain uncertainty if confidence < 0.7)"
}`;
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

  try {
    const { scan_id } = await req.json();
    if (!scan_id) {
      return new Response(
        JSON.stringify({ error: "Missing scan_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!geminiApiKey) {
      throw new Error("GEMINI_API_KEY not configured");
    }

    // Update job status
    await serviceClient
      .from("scan_jobs")
      .update({ status: "running", started_at: new Date().toISOString(), attempts: 1 })
      .eq("scan_id", scan_id)
      .eq("job_type", "diagnose_ai");

    // Update scan processing status
    await serviceClient
      .from("scans")
      .update({ processing_status: "diagnosing" })
      .eq("id", scan_id);

    // Get scan and related data
    const { data: scan, error: scanError } = await serviceClient
      .from("scans")
      .select("*, plants(*)")
      .eq("id", scan_id)
      .single();

    if (scanError || !scan) {
      throw new Error(`Scan not found: ${scan_id}`);
    }

    // Get user locale
    const { data: userProfile } = await serviceClient
      .from("users")
      .select("locale_code")
      .eq("id", scan.user_id)
      .single();

    const locale = userProfile?.locale_code ?? "en";

    // Get signed URL for the image
    const { data: signedUrlData } = await serviceClient.storage
      .from("plant-scans")
      .createSignedUrl(scan.image_path, 300); // 5 min expiry

    if (!signedUrlData?.signedUrl) {
      throw new Error("Failed to create signed URL for image");
    }

    // Download image and convert to base64
    const imageResponse = await fetch(signedUrlData.signedUrl);
    if (!imageResponse.ok) {
      throw new Error("Failed to download image");
    }

    const imageBytes = new Uint8Array(await imageResponse.arrayBuffer());
    const base64Image = btoa(String.fromCharCode(...imageBytes));

    // Build prompt
    const prompt = buildDiagnosisPrompt({
      plant: scan.plants ?? {},
      scan,
      locale,
      imageQuality: scan.image_quality_score,
    });

    // Call Gemini API
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${AI_MODEL_NAME}:generateContent?key=${geminiApiKey}`;

    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt },
              {
                inline_data: {
                  mime_type: "image/jpeg",
                  data: base64Image,
                },
              },
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
      const errorText = await geminiResponse.text();
      throw new Error(`Gemini API error: ${geminiResponse.status} ${errorText}`);
    }

    const geminiData = await geminiResponse.json();

    // Extract response text
    const responseText =
      geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    // Parse JSON response
    let diagnosis: Record<string, unknown>;
    try {
      // Try to extract JSON from the response
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        diagnosis = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error("No JSON found in response");
      }
    } catch (parseError) {
      console.error("Failed to parse Gemini response:", responseText);
      diagnosis = {
        diagnosis_code: "parse_error",
        diagnosis_localized: "Unable to parse AI response",
        treatment_localized: "Please try scanning again",
        health_score: 50,
        visual_symptoms: [],
        confidence: 0,
        uncertainty_reason: "AI response could not be parsed",
      };
    }

    // Validate and clamp values
    const healthScore = Math.max(
      0,
      Math.min(100, Math.round(Number(diagnosis.health_score) || 50))
    );
    const confidence = Math.max(
      0,
      Math.min(1, Number(diagnosis.confidence) || 0)
    );

    // Get model version from Gemini response
    const modelVersion =
      geminiData.modelVersion ?? AI_MODEL_NAME;

    // Update scan with diagnosis
    const { error: updateError } = await serviceClient
      .from("scans")
      .update({
        ai_model_name: AI_MODEL_NAME,
        ai_model_version: modelVersion,
        prompt_version: PROMPT_VERSION,
        diagnosis_confidence: confidence,
        health_score: healthScore,
        diagnosis_code: String(diagnosis.diagnosis_code ?? "unknown"),
        diagnosis_localized: String(diagnosis.diagnosis_localized ?? ""),
        treatment_localized: String(diagnosis.treatment_localized ?? ""),
        visual_symptoms: Array.isArray(diagnosis.visual_symptoms)
          ? diagnosis.visual_symptoms.map(String)
          : [],
        ai_diagnosis_raw: diagnosis,
        processing_status: "completed",
        processing_error: null,
      })
      .eq("id", scan_id);

    if (updateError) {
      throw updateError;
    }

    // Mark job as succeeded
    await serviceClient
      .from("scan_jobs")
      .update({
        status: "succeeded",
        finished_at: new Date().toISOString(),
      })
      .eq("scan_id", scan_id)
      .eq("job_type", "diagnose_ai");

    return new Response(
      JSON.stringify({
        status: "completed",
        diagnosis: {
          diagnosis_code: diagnosis.diagnosis_code,
          health_score: healthScore,
          confidence,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("diagnose-ai error:", error);

    try {
      const body = await req.clone().json().catch(() => ({}));
      const scanId = body.scan_id;
      if (scanId) {
        await serviceClient
          .from("scans")
          .update({
            processing_status: "failed",
            processing_error: error.message ?? "Unknown error",
          })
          .eq("id", scanId);

        await serviceClient
          .from("scan_jobs")
          .update({
            status: "failed",
            finished_at: new Date().toISOString(),
            error_message: error.message ?? "Unknown error",
          })
          .eq("scan_id", scanId)
          .eq("job_type", "diagnose_ai");
      }
    } catch (_) {
      // Ignore cleanup errors
    }

    return new Response(
      JSON.stringify({ error: error.message ?? "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
