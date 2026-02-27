import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getCorsHeaders } from "../_shared/cors.ts";
import { validateAuthHeader } from "../_shared/security.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const OPEN_METEO_BASE = "https://api.open-meteo.com/v1";

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/**
 * Compute Vapor Pressure Deficit (VPD) from temperature and humidity.
 * VPD = SVP * (1 - RH/100)
 * SVP = 0.6108 * exp(17.27 * T / (T + 237.3))
 */
function computeVPD(tempC: number, humidityPct: number): number {
  const svp = 0.6108 * Math.exp((17.27 * tempC) / (tempC + 237.3));
  const vpd = svp * (1 - humidityPct / 100);
  return Math.round(vpd * 1000) / 1000; // Round to 3 decimal places
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
      .eq("job_type", "enrich_weather");

    // Get scan data
    const { data: scan, error: scanError } = await serviceClient
      .from("scans")
      .select("lat_rounded, lon_rounded, geohash_6, captured_at_utc")
      .eq("id", scan_id)
      .single();

    if (scanError || !scan) {
      throw new Error(`Scan not found: ${scan_id}`);
    }

    if (!scan.lat_rounded || !scan.lon_rounded) {
      // No location data, mark as succeeded with no data
      await serviceClient
        .from("scan_jobs")
        .update({
          status: "succeeded",
          finished_at: new Date().toISOString(),
          error_message: "No location data available",
        })
        .eq("scan_id", scan_id)
        .eq("job_type", "enrich_weather");

      return new Response(
        JSON.stringify({ status: "skipped", reason: "no_location" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Query Open-Meteo API
    const capturedDate = new Date(scan.captured_at_utc);
    const dateStr = capturedDate.toISOString().split("T")[0];
    const hour = capturedDate.getUTCHours();

    const weatherUrl = new URL(`${OPEN_METEO_BASE}/forecast`);
    weatherUrl.searchParams.set("latitude", scan.lat_rounded.toString());
    weatherUrl.searchParams.set("longitude", scan.lon_rounded.toString());
    weatherUrl.searchParams.set(
      "hourly",
      "temperature_2m,relative_humidity_2m,shortwave_radiation,et0_fao_evapotranspiration,soil_temperature_0cm"
    );
    weatherUrl.searchParams.set("start_date", dateStr);
    weatherUrl.searchParams.set("end_date", dateStr);
    weatherUrl.searchParams.set("timezone", "UTC");

    const weatherResponse = await fetch(weatherUrl.toString());
    if (!weatherResponse.ok) {
      throw new Error(
        `Open-Meteo API error: ${weatherResponse.status} ${await weatherResponse.text()}`
      );
    }

    const weatherData = await weatherResponse.json();
    const hourly = weatherData?.hourly;

    if (!hourly || !hourly.time || hourly.time.length === 0) {
      throw new Error("No hourly data returned from Open-Meteo");
    }

    // Find closest hour index
    const hourIndex = Math.min(hour, hourly.time.length - 1);

    const tempC = hourly.temperature_2m?.[hourIndex] ?? null;
    const humidityPct = hourly.relative_humidity_2m?.[hourIndex] ?? null;
    const solarRadiation = hourly.shortwave_radiation?.[hourIndex] ?? null;
    const et0 = hourly.et0_fao_evapotranspiration?.[hourIndex] ?? null;
    const soilTemp = hourly.soil_temperature_0cm?.[hourIndex] ?? null;

    // Compute VPD
    let vpd: number | null = null;
    if (tempC !== null && humidityPct !== null) {
      vpd = computeVPD(tempC, humidityPct);
    }

    // Update scan with weather data
    const { error: updateError } = await serviceClient
      .from("scans")
      .update({
        temp_c: tempC,
        humidity_pct: humidityPct,
        vpd_kpa: vpd,
        solar_radiation_wm2: solarRadiation,
        et0_mm: et0,
        soil_temp_0cm_c: soilTemp,
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
      .eq("job_type", "enrich_weather");

    return new Response(
      JSON.stringify({
        status: "succeeded",
        data: {
          temp_c: tempC,
          humidity_pct: humidityPct,
          vpd_kpa: vpd,
          solar_radiation_wm2: solarRadiation,
          et0_mm: et0,
          soil_temp_0cm_c: soilTemp,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("enrich-weather error:", error);

    // Update job as failed
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
          .eq("job_type", "enrich_weather");
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
