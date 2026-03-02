import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { validateAuthHeader } from "./security.ts";

async function sha256(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

type B2BAuthResult = {
  mode: "jwt" | "b2b";
  companyName?: string;
  tierLimit?: number;
};

export async function validateAuthOrB2BApiKey(
  req: Request,
  corsHeaders: Record<string, string>,
  serviceClient: SupabaseClient,
): Promise<Response | B2BAuthResult> {
  const apiKey = req.headers.get("x-api-key")?.trim();
  if (apiKey) {
    const hashedApiKey = await sha256(apiKey);
    const { data, error } = await serviceClient
      .from("b2b_api_keys")
      .select("company_name, tier_limit")
      .eq("api_key", hashedApiKey)
      .maybeSingle();

    if (error || !data) {
      return new Response(JSON.stringify({ error: "Invalid x-api-key" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return {
      mode: "b2b",
      companyName: data.company_name as string,
      tierLimit: data.tier_limit as number,
    };
  }

  const authError = validateAuthHeader(req, corsHeaders);
  if (authError) return authError;
  return { mode: "jwt" };
}
