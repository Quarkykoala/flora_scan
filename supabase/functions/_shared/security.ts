// Security utilities for Supabase Edge Functions

/**
 * Validates the Authorization header from the request.
 * Ensure it exists and follows the 'Bearer <token>' format.
 *
 * @param req The incoming Request object
 * @param corsHeaders CORS headers to include in error responses
 * @returns An error Response if validation fails, or null if valid.
 */
export function validateAuthHeader(req: Request, corsHeaders: Record<string, string>): Response | null {
  const authHeader = req.headers.get("Authorization");

  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: "Missing authorization header" }),
      {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  // Check for 'Bearer ' prefix (case-insensitive for robustness)
  if (!authHeader.trim().match(/^Bearer\s+/i)) {
    return new Response(
      JSON.stringify({
        error: "Invalid authorization header format. Expected 'Bearer <token>'",
      }),
      {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  return null;
}
