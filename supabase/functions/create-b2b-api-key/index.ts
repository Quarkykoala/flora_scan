import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import { getCorsHeaders } from "../_shared/cors.ts";
import { sha256Hex } from "../_shared/hash.ts";

function errMsg(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function generateApiKey(): string {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  const encoded = btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
  return `fls_live_${encoded}`;
}

serve(async (req: Request) => {
  const corsHeaders = getCorsHeaders(req.headers.get("Origin"));
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const adminToken = Deno.env.get("B2B_ADMIN_TOKEN")?.trim();
  const suppliedToken = req.headers.get("x-admin-token")?.trim();
  if (!adminToken || suppliedToken != adminToken) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const serviceClient = createClient(supabaseUrl, serviceKey);

  try {
    const body = await req.json();
    const companyName = String(body.company_name ?? "").trim();
    const tierLimitRaw = Number(body.tier_limit ?? 1000);
    const tierLimit = Number.isFinite(tierLimitRaw) && tierLimitRaw > 0
      ? Math.round(tierLimitRaw)
      : 1000;

    if (!companyName) {
      return new Response(JSON.stringify({ error: "Missing company_name" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const plaintextKey = generateApiKey();
    const hashedKey = await sha256Hex(plaintextKey);

    const { data, error } = await serviceClient
      .from("b2b_api_keys")
      .insert({
        company_name: companyName,
        api_key: hashedKey,
        tier_limit: tierLimit,
      })
      .select("id, company_name, tier_limit, created_at")
      .single();

    if (error) throw error;

    return new Response(JSON.stringify({
      status: "ok",
      key: {
        ...data,
        api_key_plaintext: plaintextKey,
      },
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: errMsg(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

