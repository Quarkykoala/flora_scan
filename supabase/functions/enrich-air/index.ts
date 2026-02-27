import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getCorsHeaders } from "../_shared/cors.ts";
import { validateAuthHeader } from "../_shared/security.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

serve(async (req: Request) => {
  const corsHeaders = getCorsHeaders(req.headers.get("Origin"));

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Validate Authorization header
  const authError = validateAuthHeader(req, corsHeaders);
  if (authError) return authError;

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const googleMapsApiKey = Deno.env.get("GOOGLE_MAPS_API_KEY");
  const serviceClient = createClient(supabaseUrl, supabaseServiceKey);

  try {
    const { scan_id } = await req.json();
    if (!scan_id) {
      return new Response(
        JSON.stringify({ error: "Missing scan_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Update job status
    await serviceClient
      .from("scan_jobs")
      .update({ status: "running", started_at: new Date().toISOString(), attempts: 1 })
      .eq("scan_id", scan_id)
      .eq("job_type", "enrich_air");

    // Get scan data
    const { data: scan, error: scanError } = await serviceClient
      .from("scans")
      .select("lat_rounded, lon_rounded, geohash_6")
      .eq("id", scan_id)
      .single();

    if (scanError || !scan) {
      throw new Error(`Scan not found: ${scan_id}`);
    }

    if (!scan.lat_rounded || !scan.lon_rounded) {
      await serviceClient
        .from("scan_jobs")
        .update({
          status: "succeeded",
          finished_at: new Date().toISOString(),
          error_message: "No location data available",
        })
        .eq("scan_id", scan_id)
        .eq("job_type", "enrich_air");

      return new Response(
        JSON.stringify({ status: "skipped", reason: "no_location" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!googleMapsApiKey) {
      await serviceClient
        .from("scan_jobs")
        .update({
          status: "failed",
          finished_at: new Date().toISOString(),
          error_message: "GOOGLE_MAPS_API_KEY not configured",
        })
        .eq("scan_id", scan_id)
        .eq("job_type", "enrich_air");

      return new Response(
        JSON.stringify({ status: "skipped", reason: "no_api_key" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Query Google Maps Air Quality API
    const aqUrl = `https://airquality.googleapis.com/v1/currentConditions:lookup?key=${googleMapsApiKey}`;

    const aqResponse = await fetch(aqUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        location: {
          latitude: scan.lat_rounded,
          longitude: scan.lon_rounded,
        },
        extraComputations: [
          "POLLUTANT_CONCENTRATION",
          "LOCAL_AQI",
          "POLLUTANT_ADDITIONAL_INFO",
        ],
      }),
    });

    if (!aqResponse.ok) {
      throw new Error(
        `Air Quality API error: ${aqResponse.status} ${await aqResponse.text()}`
      );
    }

    const aqData = await aqResponse.json();

    // Extract AQI and pollutant data
    let aqi: number | null = null;
    let pm25: number | null = null;
    let pm10: number | null = null;
    let no2: number | null = null;
    let o3: number | null = null;

    // Get overall AQI from indexes
    if (aqData.indexes && aqData.indexes.length > 0) {
      aqi = aqData.indexes[0].aqi ?? null;
    }

    // Extract pollutant concentrations
    if (aqData.pollutants) {
      for (const pollutant of aqData.pollutants) {
        const concentration = pollutant.concentration?.value ?? null;
        switch (pollutant.code) {
          case "pm25":
            pm25 = concentration;
            break;
          case "pm10":
            pm10 = concentration;
            break;
          case "no2":
            no2 = concentration;
            break;
          case "o3":
            o3 = concentration;
            break;
        }
      }
    }

    // Update scan with air quality data
    const { error: updateError } = await serviceClient
      .from("scans")
      .update({
        aqi: aqi,
        pm2_5: pm25,
        pm10: pm10,
        no2: no2,
        o3: o3,
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
      .eq("job_type", "enrich_air");

    return new Response(
      JSON.stringify({
        status: "succeeded",
        data: { aqi, pm2_5: pm25, pm10, no2, o3 },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("enrich-air error:", error);

    try {
      const { scan_id } = await req.clone().json().catch(() => ({ scan_id: null }));
      if (scan_id) {
        await serviceClient
          .from("scan_jobs")
          .update({
            status: "failed",
            finished_at: new Date().toISOString(),
            error_message: errorMessage(error) || "Unknown error",
          })
          .eq("scan_id", scan_id)
          .eq("job_type", "enrich_air");
      }
    } catch (_) {
      // Ignore cleanup errors
    }

    return new Response(
      JSON.stringify({ error: errorMessage(error) || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
