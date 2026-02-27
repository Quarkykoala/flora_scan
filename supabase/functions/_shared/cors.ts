export const corsHeaders = {
  "Access-Control-Allow-Origin": "",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export const getCorsHeaders = (requestOrigin: string | null) => {
  const allowedOrigins = [
    "http://localhost:3000",
    "http://localhost:54321",
    "https://app.florascan.com",
    "https://florascan.com",
  ];

  // If no origin is provided (e.g. direct curl call), default to strict
  if (!requestOrigin) {
    return { ...corsHeaders, "Access-Control-Allow-Origin": "null" };
  }

  // Allow dynamic origin matching for development/preview environments
  const isAllowed = allowedOrigins.includes(requestOrigin) ||
    requestOrigin.endsWith(".florascan.com"); // Allow subdomains like preview-pr-123.florascan.com

  if (isAllowed) {
    return { ...corsHeaders, "Access-Control-Allow-Origin": requestOrigin };
  }

  return { ...corsHeaders, "Access-Control-Allow-Origin": "null" };
};
