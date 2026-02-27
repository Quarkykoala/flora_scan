// Security Tests for Authorization Header Validation
import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { validateAuthHeader } from "../_shared/security.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
};

Deno.test("validateAuthHeader - Valid Header", () => {
  const req = new Request("http://localhost", {
    headers: { Authorization: "Bearer my-secret-token" },
  });
  const result = validateAuthHeader(req, corsHeaders);
  assertEquals(result, null, "Should return null for valid Bearer token");
});

Deno.test("validateAuthHeader - Missing Header", async () => {
  const req = new Request("http://localhost");
  const result = validateAuthHeader(req, corsHeaders);

  assertEquals(result instanceof Response, true, "Should return Response for missing header");
  assertEquals(result?.status, 401);
  const body = await result?.json();
  assertEquals(body.error, "Missing authorization header");
  assertEquals(result?.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("validateAuthHeader - Empty Header", async () => {
  const req = new Request("http://localhost", {
    headers: { Authorization: "" },
  });
  const result = validateAuthHeader(req, corsHeaders);

  assertEquals(result instanceof Response, true, "Should return Response for empty header");
  assertEquals(result?.status, 401);
  const body = await result?.json();
  assertEquals(body.error, "Missing authorization header");
});

Deno.test("validateAuthHeader - Missing Bearer Prefix", async () => {
  const req = new Request("http://localhost", {
    headers: { Authorization: "my-secret-token" },
  });
  const result = validateAuthHeader(req, corsHeaders);

  assertEquals(result instanceof Response, true, "Should return Response for invalid format");
  assertEquals(result?.status, 401);
  const body = await result?.json();
  assertEquals(body.error, "Invalid authorization header format. Expected 'Bearer <token>'");
});

Deno.test("validateAuthHeader - Wrong Prefix", async () => {
  const req = new Request("http://localhost", {
    headers: { Authorization: "Basic dXNlcjpwYXNz" },
  });
  const result = validateAuthHeader(req, corsHeaders);

  assertEquals(result instanceof Response, true, "Should return Response for wrong prefix");
  assertEquals(result?.status, 401);
  const body = await result?.json();
  assertEquals(body.error, "Invalid authorization header format. Expected 'Bearer <token>'");
});

Deno.test("validateAuthHeader - Case Insensitivity", () => {
  const req = new Request("http://localhost", {
    headers: { Authorization: "bearer my-secret-token" },
  });
  const result = validateAuthHeader(req, corsHeaders);
  assertEquals(result, null, "Should accept 'bearer' (case insensitive)");
});

Deno.test("validateAuthHeader - Extra Spaces", () => {
  const req = new Request("http://localhost", {
    headers: { Authorization: "   Bearer    my-secret-token   " },
  });
  const result = validateAuthHeader(req, corsHeaders);
  assertEquals(result, null, "Should handle extra whitespace gracefully (regex allows spaces)");
});
