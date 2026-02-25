import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface CreateScanRequest {
  client_scan_id: string;
  plant_id: string;
  captured_at_utc: string;
  image_path: string;
  image_width?: number;
  image_height?: number;
  image_sha256?: string;
  device_platform?: string;
  app_version?: string;
  device_tz?: string;
  lat_precise?: number;
  lon_precise?: number;
  lat_rounded?: number;
  lon_rounded?: number;
  geohash_6?: string;
  altitude_meters?: number;
  location_accuracy_meters?: number;
  lux_reading?: number;
  lux_source?: string;
  device_pitch_deg?: number;
  device_roll_deg?: number;
  flash_fired?: boolean;
  image_quality_score?: number;
  telemetry_completeness_score?: number;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // Create client with user's auth token for user identification
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Create service client for database operations
    const serviceClient = createClient(supabaseUrl, supabaseServiceKey);

    const body: CreateScanRequest = await req.json();

    // Validate required fields
    if (!body.client_scan_id || !body.plant_id || !body.captured_at_utc || !body.image_path) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: client_scan_id, plant_id, captured_at_utc, image_path" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check research consent for precise coordinates
    const { data: userProfile } = await serviceClient
      .from("users")
      .select("research_consent")
      .eq("id", user.id)
      .single();

    const researchConsent = userProfile?.research_consent ?? false;

    // Build scan record
    const scanRecord: Record<string, unknown> = {
      user_id: user.id,
      plant_id: body.plant_id,
      client_scan_id: body.client_scan_id,
      captured_at_utc: body.captured_at_utc,
      uploaded_at_utc: new Date().toISOString(),
      image_path: body.image_path,
      image_sha256: body.image_sha256,
      image_width: body.image_width,
      image_height: body.image_height,
      device_platform: body.device_platform,
      app_version: body.app_version,
      device_tz: body.device_tz,
      // Privacy-aware geospatial
      lat_precise: researchConsent ? body.lat_precise : null,
      lon_precise: researchConsent ? body.lon_precise : null,
      lat_rounded: body.lat_rounded,
      lon_rounded: body.lon_rounded,
      geohash_6: body.geohash_6,
      altitude_meters: body.altitude_meters,
      location_accuracy_meters: body.location_accuracy_meters,
      // Hardware telemetry
      lux_reading: body.lux_reading,
      lux_source: body.lux_source,
      device_pitch_deg: body.device_pitch_deg,
      device_roll_deg: body.device_roll_deg,
      flash_fired: body.flash_fired,
      // Quality scores
      image_quality_score: body.image_quality_score,
      telemetry_completeness_score: body.telemetry_completeness_score,
      processing_status: "queued",
    };

    // Insert scan record
    const { data: scan, error: scanError } = await serviceClient
      .from("scans")
      .insert(scanRecord)
      .select("id")
      .single();

    if (scanError) {
      // Check for duplicate client_scan_id
      if (scanError.code === "23505") {
        const { data: existingScan } = await serviceClient
          .from("scans")
          .select("id, processing_status")
          .eq("client_scan_id", body.client_scan_id)
          .single();

        return new Response(
          JSON.stringify({
            scan_id: existingScan?.id,
            status: existingScan?.processing_status,
            duplicate: true,
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      throw scanError;
    }

    const scanId = scan.id;

    // Enqueue processing jobs
    const jobs = [
      { scan_id: scanId, job_type: "enrich_weather", status: "queued" },
      { scan_id: scanId, job_type: "enrich_air", status: "queued" },
      { scan_id: scanId, job_type: "diagnose_ai", status: "queued" },
    ];

    // Only enqueue weather/air jobs if we have location data
    const jobsToInsert = body.geohash_6
      ? jobs
      : [{ scan_id: scanId, job_type: "diagnose_ai", status: "queued" }];

    const { error: jobsError } = await serviceClient
      .from("scan_jobs")
      .insert(jobsToInsert);

    if (jobsError) {
      console.error("Failed to enqueue jobs:", jobsError);
    }

    // Update processing status
    await serviceClient
      .from("scans")
      .update({ processing_status: "enriching" })
      .eq("id", scanId);

    // Trigger enrichment functions asynchronously
    if (body.geohash_6) {
      // Fire and forget: trigger weather enrichment
      fetch(`${supabaseUrl}/functions/v1/enrich-weather`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${supabaseServiceKey}`,
        },
        body: JSON.stringify({ scan_id: scanId }),
      }).catch((e) => console.error("Failed to trigger enrich-weather:", e));

      // Fire and forget: trigger air quality enrichment
      fetch(`${supabaseUrl}/functions/v1/enrich-air`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${supabaseServiceKey}`,
        },
        body: JSON.stringify({ scan_id: scanId }),
      }).catch((e) => console.error("Failed to trigger enrich-air:", e));
    }

    // Fire and forget: trigger AI diagnosis
    fetch(`${supabaseUrl}/functions/v1/diagnose-ai`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${supabaseServiceKey}`,
      },
      body: JSON.stringify({ scan_id: scanId }),
    }).catch((e) => console.error("Failed to trigger diagnose-ai:", e));

    return new Response(
      JSON.stringify({
        scan_id: scanId,
        status: "enriching",
        jobs_enqueued: jobsToInsert.length,
      }),
      { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("create-scan error:", error);
    return new Response(
      JSON.stringify({ error: error.message ?? "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
