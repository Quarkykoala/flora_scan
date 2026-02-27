import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getCorsHeaders } from "../_shared/cors.ts";
import { validateAuthHeader } from "../_shared/security.ts";
import { fetchPlantKnowledge } from "../_shared/plant-knowledge.ts";

const CHAT_PROMPT_VERSION = "1.0.0";
const CHAT_MODEL_NAME = "gemini-2.0-flash";

type ChatBody = {
  plant_id?: string | null;
  locale?: string | null;
  messages?: Array<{ role: "user" | "assistant"; text: string }>;
};

function json(
  payload: Record<string, unknown>,
  status: number,
  corsHeaders: HeadersInit,
): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function compactMessages(
  input: ChatBody["messages"],
): Array<{ role: "user" | "assistant"; text: string }> {
  if (!Array.isArray(input)) return [];
  return input
    .filter((m) => m && (m.role === "user" || m.role === "assistant"))
    .map((m) => ({ role: m.role, text: String(m.text ?? "").trim() }))
    .filter((m) => m.text.length > 0)
    .slice(-10);
}

serve(async (req: Request) => {
  const corsHeaders = getCorsHeaders(req.headers.get("Origin"));

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authError = validateAuthHeader(req, corsHeaders);
  if (authError) return authError;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY");

  if (!supabaseUrl || !supabaseServiceKey) {
    return json({ error: "Supabase env is missing" }, 500, corsHeaders);
  }
  if (!geminiApiKey) {
    return json({ error: "GEMINI_API_KEY not configured" }, 500, corsHeaders);
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "").trim();

    const serviceClient = createClient(supabaseUrl, supabaseServiceKey);
    const {
      data: { user },
      error: userErr,
    } = await serviceClient.auth.getUser(jwt);
    if (userErr || !user) {
      return json({ error: "Unauthorized" }, 401, corsHeaders);
    }

    const body = (await req.json()) as ChatBody;
    const messages = compactMessages(body.messages);
    const lastUserMessage = [...messages].reverse().find((m) => m.role === "user");
    if (!lastUserMessage) {
      return json({ error: "No user message provided" }, 400, corsHeaders);
    }

    const locale = body.locale ?? "en";
    let plantContext = "No plant selected.";
    let scanContext = "No latest scan context available.";
    let knowledgeSummary = "No external plant API knowledge available.";

    if (body.plant_id) {
      const { data: plant } = await serviceClient
        .from("plants")
        .select("id, nickname, species_scientific, species_common, environment_profile")
        .eq("id", body.plant_id)
        .eq("user_id", user.id)
        .maybeSingle();

      if (plant) {
        plantContext = JSON.stringify(plant);
        const speciesHint = String(plant.species_scientific ?? plant.species_common ?? "");
        const knowledge = await fetchPlantKnowledge(speciesHint);
        knowledgeSummary = knowledge.summary;

        const { data: latestScan } = await serviceClient
          .from("scans")
          .select(
            "captured_at_utc, temp_c, humidity_pct, vpd_kpa, lux_reading, aqi, diagnosis_code, diagnosis_localized, treatment_localized, health_score, diagnosis_confidence",
          )
          .eq("plant_id", body.plant_id)
          .eq("user_id", user.id)
          .order("captured_at_utc", { ascending: false })
          .limit(1)
          .maybeSingle();

        if (latestScan) {
          scanContext = JSON.stringify(latestScan);
        }
      }
    }

    const history = messages
      .map((m) => `${m.role.toUpperCase()}: ${m.text}`)
      .join("\n");

    const prompt = `You are FloraScan Assistant. Keep answers concise, practical, and safe for household plant care.
Reply in locale: ${locale}
Never provide high-risk chemical dosage instructions.
If uncertain, explicitly say uncertainty and ask for another scan/photo.

Plant context: ${plantContext}
Latest scan context: ${scanContext}
External plant knowledge: ${knowledgeSummary}

Conversation:
${history}

Return strict JSON:
{
  "answer": "string",
  "urgency": "low|medium|high",
  "suggested_actions": ["string"],
  "confidence": 0.0
}`;

    const geminiUrl =
      `https://generativelanguage.googleapis.com/v1beta/models/${CHAT_MODEL_NAME}:generateContent?key=${geminiApiKey}`;

    const response = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.3,
          topP: 0.8,
          maxOutputTokens: 1024,
          responseMimeType: "application/json",
        },
      }),
    });

    if (!response.ok) {
      return json(
        { error: `Gemini API error: ${response.status} ${await response.text()}` },
        500,
        corsHeaders,
      );
    }

    const responseBody = await response.json();
    const text = responseBody.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
    const match = text.match(/\{[\s\S]*\}/);
    const parsed = match ? JSON.parse(match[0]) : {};

    return json(
      {
        answer: String(parsed.answer ?? "I need a clearer question to help."),
        urgency: ["low", "medium", "high"].includes(String(parsed.urgency))
          ? parsed.urgency
          : "low",
        suggested_actions: Array.isArray(parsed.suggested_actions)
          ? parsed.suggested_actions.map(String).slice(0, 4)
          : [],
        confidence: Math.max(0, Math.min(1, Number(parsed.confidence) || 0.5)),
        model_name: CHAT_MODEL_NAME,
        prompt_version: CHAT_PROMPT_VERSION,
      },
      200,
      corsHeaders,
    );
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
      corsHeaders,
    );
  }
});
