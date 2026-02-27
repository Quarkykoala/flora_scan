import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getCorsHeaders } from "../_shared/cors.ts";
import { validateAuthHeader } from "../_shared/security.ts";

const VALID_ADHERENCE = new Set(["fully", "partially", "not_done", "unknown"]);
const VALID_OUTCOME = new Set(["improved", "unchanged", "worse", "uncertain"]);
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

serve(async (req: Request) => {
  const corsHeaders = getCorsHeaders(req.headers.get("Origin"));

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authError = validateAuthHeader(req, corsHeaders);
  if (authError) return authError;

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const authHeader = req.headers.get("Authorization")!;

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const serviceClient = createClient(supabaseUrl, supabaseServiceKey);

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const interventionId = String(body.intervention_id ?? "").trim();
    const adherenceStatus = String(body.adherence_status ?? "unknown").trim().toLowerCase();
    const outcomeStatus = String(body.outcome_status ?? "uncertain").trim().toLowerCase();
    const followupScanId =
      body.followup_scan_id != null ? String(body.followup_scan_id).trim() : null;
    const outcomeConfidence =
      body.outcome_confidence != null ? Number(body.outcome_confidence) : null;
    const followupImageQualityScore =
      body.followup_image_quality_score != null
        ? Number(body.followup_image_quality_score)
        : null;

    if (!interventionId) {
      return new Response(JSON.stringify({ error: "Missing intervention_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!UUID_REGEX.test(interventionId)) {
      return new Response(JSON.stringify({ error: "Invalid intervention_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!VALID_ADHERENCE.has(adherenceStatus)) {
      return new Response(JSON.stringify({ error: "Invalid adherence_status" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!VALID_OUTCOME.has(outcomeStatus)) {
      return new Response(JSON.stringify({ error: "Invalid outcome_status" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (outcomeConfidence !== null && (!Number.isFinite(outcomeConfidence) || outcomeConfidence < 0 || outcomeConfidence > 1)) {
      return new Response(JSON.stringify({ error: "Invalid outcome_confidence" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (
      followupImageQualityScore !== null &&
      (!Number.isFinite(followupImageQualityScore) ||
        followupImageQualityScore < 0 ||
        followupImageQualityScore > 1)
    ) {
      return new Response(JSON.stringify({ error: "Invalid followup_image_quality_score" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (followupScanId && !UUID_REGEX.test(followupScanId)) {
      return new Response(JSON.stringify({ error: "Invalid followup_scan_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: intervention, error: interventionError } = await serviceClient
      .from("intervention_recommendations")
      .select("id, user_id, plant_id, recommended_at_utc")
      .eq("id", interventionId)
      .single();

    if (interventionError || !intervention) {
      return new Response(JSON.stringify({ error: "Intervention not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (intervention.user_id !== user.id) {
      return new Response(JSON.stringify({ error: "Forbidden" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (followupScanId) {
      const { data: followupScan, error: followupScanError } = await serviceClient
        .from("scans")
        .select("id")
        .eq("id", followupScanId)
        .eq("user_id", user.id)
        .eq("plant_id", intervention.plant_id)
        .maybeSingle();

      if (followupScanError || !followupScan) {
        return new Response(JSON.stringify({ error: "Invalid followup_scan_id for this plant" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const recordedAt = new Date();
    const recommendedAt = new Date(intervention.recommended_at_utc);
    const daysSinceRecommendation = Math.max(
      0,
      Math.floor((recordedAt.getTime() - recommendedAt.getTime()) / (24 * 60 * 60 * 1000)),
    );

    const outcomePayload = {
      intervention_id: intervention.id,
      user_id: user.id,
      plant_id: intervention.plant_id,
      adherence_status: adherenceStatus,
      adherence_notes:
        body.adherence_notes != null ? String(body.adherence_notes) : null,
      outcome_status: outcomeStatus,
      outcome_confidence: outcomeConfidence,
      outcome_notes: body.outcome_notes != null ? String(body.outcome_notes) : null,
      followup_scan_id: followupScanId,
      followup_image_quality_score: followupImageQualityScore,
      days_since_recommendation: daysSinceRecommendation,
      reported_by: "user",
      recorded_at_utc: recordedAt.toISOString(),
    };

    const { data: existingOutcome } = await serviceClient
      .from("intervention_outcomes")
      .select("id")
      .eq("intervention_id", intervention.id)
      .eq("user_id", user.id)
      .order("recorded_at_utc", { ascending: false })
      .limit(1)
      .maybeSingle();

    let outcomeId: string;
    if (existingOutcome?.id) {
      const { error: updateOutcomeError } = await serviceClient
        .from("intervention_outcomes")
        .update(outcomePayload)
        .eq("id", existingOutcome.id)
        .eq("user_id", user.id);
      if (updateOutcomeError) throw updateOutcomeError;
      outcomeId = existingOutcome.id;
    } else {
      const { data: outcome, error: insertError } = await serviceClient
        .from("intervention_outcomes")
        .insert(outcomePayload)
        .select("id")
        .single();
      if (insertError || !outcome) throw insertError;
      outcomeId = outcome.id;
    }

    const { error: interventionUpdateError } = await serviceClient
      .from("intervention_recommendations")
      .update({ followup_status: "completed", updated_at: new Date().toISOString() })
      .eq("id", interventionId)
      .eq("user_id", user.id);
    if (interventionUpdateError) throw interventionUpdateError;

    const { error: missionUpdateError } = await serviceClient
      .from("followup_missions")
      .update({ status: "completed", completed_at_utc: new Date().toISOString() })
      .eq("intervention_id", interventionId)
      .eq("user_id", user.id)
      .eq("mission_type", "log_outcome")
      .eq("status", "pending");
    if (missionUpdateError) throw missionUpdateError;

    return new Response(
      JSON.stringify({ status: "ok", outcome_id: outcomeId }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("submit-intervention-outcome error:", error);
    return new Response(
      JSON.stringify({ error: error.message ?? "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
