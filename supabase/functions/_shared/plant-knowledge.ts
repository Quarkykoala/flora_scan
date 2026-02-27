export type PlantKnowledge = {
  provider: "perenual" | "none";
  summary: string;
  raw?: Record<string, unknown> | null;
};

function toSingleLine(input: unknown): string | null {
  if (typeof input !== "string") return null;
  const normalized = input.replace(/\s+/g, " ").trim();
  return normalized.length > 0 ? normalized : null;
}

export async function fetchPlantKnowledge(
  speciesHint: string | null | undefined,
): Promise<PlantKnowledge> {
  if (!speciesHint || !speciesHint.trim()) {
    return {
      provider: "none",
      summary: "No species hint available for external knowledge lookup.",
      raw: null,
    };
  }

  const apiKey = Deno.env.get("PERENUAL_API_KEY");
  if (!apiKey) {
    return {
      provider: "none",
      summary: "External plant knowledge API key is not configured.",
      raw: null,
    };
  }

  try {
    const url = new URL("https://perenual.com/api/species-care-guide-list");
    url.searchParams.set("key", apiKey);
    url.searchParams.set("q", speciesHint.trim());

    const response = await fetch(url.toString());
    if (!response.ok) {
      return {
        provider: "none",
        summary: `Plant API lookup failed with status ${response.status}.`,
        raw: null,
      };
    }

    const payload = await response.json();
    const first = Array.isArray(payload?.data) ? payload.data[0] : null;

    if (!first || typeof first !== "object") {
      return {
        provider: "none",
        summary: "No plant API result matched the provided species hint.",
        raw: payload ?? null,
      };
    }

    const care = first.section ?? {};
    const watering = toSingleLine(care.watering);
    const sunlight = toSingleLine(care.sunlight);
    const pruning = toSingleLine(care.pruning);
    const soil = toSingleLine(care.soil);

    const summaryParts = [
      watering ? `Watering: ${watering}` : null,
      sunlight ? `Sunlight: ${sunlight}` : null,
      soil ? `Soil: ${soil}` : null,
      pruning ? `Pruning: ${pruning}` : null,
    ].filter((v): v is string => v != null);

    return {
      provider: "perenual",
      summary: summaryParts.length > 0
          ? summaryParts.join(" | ")
          : "Plant API returned limited care guidance.",
      raw: first as Record<string, unknown>,
    };
  } catch (error) {
    return {
      provider: "none",
      summary: `Plant API lookup failed: ${error instanceof Error ? error.message : String(error)}`,
      raw: null,
    };
  }
}
