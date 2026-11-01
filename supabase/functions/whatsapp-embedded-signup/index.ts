import { createClient } from "jsr:@supabase/supabase-js@2";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const VERSION = Deno.env.get("META_GRAPH_API_VERSION") || "v26.0";
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, "content-type": "application/json", "cache-control": "no-store" },
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  const auth = req.headers.get("Authorization") || "";
  if (!auth.startsWith("Bearer ")) return reply({ error: "Authentication required" }, 401);
  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const userClient = createClient(url, anon, { global: { headers: { Authorization: auth } } });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return reply({ error: "Invalid session" }, 401);
  const db = createClient(url, service, { auth: { persistSession: false } });
  const { data: admin, error: adminError } = await db.from("admin_users")
    .select("user_id").eq("user_id", userData.user.id).maybeSingle();
  if (adminError || !admin) return reply({ error: "Admin access required" }, 403);

  let body: any;
  try { body = await req.json(); } catch { return reply({ error: "Invalid JSON" }, 400); }
  const code = typeof body?.code === "string" ? body.code.trim() : "";
  const wabaId = typeof body?.waba_id === "string" ? body.waba_id.trim() : "";
  let phoneId = typeof body?.phone_number_id === "string" ? body.phone_number_id.trim() : "";
  if (!code || !/^[0-9]{5,30}$/.test(wabaId)) return reply({ error: "Authorization code and valid WABA ID are required" }, 400);
  if (phoneId && !/^[0-9]{5,30}$/.test(phoneId)) return reply({ error: "Invalid phone number ID" }, 400);
  const appId = Deno.env.get("META_APP_ID") || "1084120231126076";
  const appSecret = Deno.env.get("META_APP_SECRET");
  if (!appSecret) return reply({ error: "META_APP_SECRET is not configured" }, 503);

  const tokenUrl = new URL("https://graph.facebook.com/" + VERSION + "/oauth/access_token");
  tokenUrl.searchParams.set("client_id", appId);
  tokenUrl.searchParams.set("client_secret", appSecret);
  tokenUrl.searchParams.set("code", code);
  const tokenResponse = await fetch(tokenUrl);
  const tokenData: any = await tokenResponse.json().catch(() => ({}));
  if (!tokenResponse.ok || !tokenData.access_token) {
    console.error("WhatsApp signup token exchange failed", tokenData.error?.code || tokenResponse.status);
    return reply({ error: "Meta code exchange failed. Restart Embedded Signup and retry once." }, 502);
  }

  let displayPhone: string | null = null;
  let verifiedName: string | null = null;
  const phoneUrl = new URL("https://graph.facebook.com/" + VERSION + "/" + wabaId + "/phone_numbers");
  phoneUrl.searchParams.set("fields", "id,display_phone_number,verified_name");
  const phoneResponse = await fetch(phoneUrl, { headers: { Authorization: "Bearer " + tokenData.access_token } });
  const phoneData: any = await phoneResponse.json().catch(() => ({}));
  if (phoneResponse.ok && Array.isArray(phoneData.data)) {
    if (!phoneId && phoneData.data.length === 1) phoneId = String(phoneData.data[0].id);
    const match = phoneData.data.find((p: any) => String(p.id) === phoneId);
    if (match) { displayPhone = match.display_phone_number ?? null; verifiedName = match.verified_name ?? null; }
  }
  const seconds = Number(tokenData.expires_in);
  const expiry = Number.isFinite(seconds) && seconds > 0 ? new Date(Date.now() + seconds * 1000).toISOString() : null;
  const { error } = await db.from("whatsapp_connections").upsert({
    waba_id: wabaId, phone_number_id: phoneId || null, display_phone_number: displayPhone,
    verified_name: verifiedName, access_token: tokenData.access_token, token_expires_at: expiry,
    connection_mode: "coexistence", status: "pending_webhook", updated_at: new Date().toISOString(),
  }, { onConflict: "waba_id" });
  if (error) {
    console.error("WhatsApp credential storage failed", error.code);
    return reply({ error: "Connection details could not be stored securely. Check database migration." }, 500);
  }
  return reply({ ok: true, waba_id: wabaId, phone_number_id: phoneId || null,
    display_phone_number: displayPhone, verified_name: verifiedName,
    token_expires_at: expiry, status: "pending_webhook" });
});
