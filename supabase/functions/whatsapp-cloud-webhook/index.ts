import { createClient } from "jsr:@supabase/supabase-js@2";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

function safeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function validSignature(raw: string, signature: string, secret: string) {
  const match = /^sha256=([0-9a-f]{64})$/i.exec(signature);
  if (!match) return false;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const digest = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(raw)));
  const expected = Array.from(digest, b => b.toString(16).padStart(2, "0")).join("");
  return safeEqual(expected, match[1].toLowerCase());
}

function lastFour(value: unknown): string | null {
  const digits = String(value ?? "").replace(/\D/g, "");
  return digits.length >= 4 ? digits.slice(-4) : null;
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  if (req.method === "GET") {
    const supplied = url.searchParams.get("hub.verify_token") || "";
    const expected = Deno.env.get("META_WHATSAPP_VERIFY_TOKEN") || "";
    if (url.searchParams.get("hub.mode") === "subscribe" &&
      url.searchParams.get("hub.challenge") && expected && safeEqual(supplied, expected)) {
      return new Response(url.searchParams.get("hub.challenge"), { status: 200 });
    }
    return new Response("Forbidden", { status: 403 });
  }
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const raw = await req.text();
  if (raw.length > 1_000_000) return new Response("Payload too large", { status: 413 });
  const secret = Deno.env.get("META_APP_SECRET") || "";
  if (!secret) return json({ error: "Webhook signing secret is not configured" }, 503);
  if (!(await validSignature(raw, req.headers.get("x-hub-signature-256") || "", secret))) {
    return new Response("Invalid signature", { status: 401 });
  }

  let payload: any;
  try { payload = JSON.parse(raw); } catch { return new Response("Invalid JSON", { status: 400 }); }
  if (payload?.object !== "whatsapp_business_account") return json({ ok: true, ignored: true });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return json({ error: "Backend configuration unavailable" }, 503);
  const db = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let received = 0, saved = 0, duplicates = 0, failed = 0;
  for (const entry of Array.isArray(payload.entry) ? payload.entry : []) {
    for (const change of Array.isArray(entry?.changes) ? entry.changes : []) {
      const field = String(change?.field || "unknown");
      const value = change?.value && typeof change.value === "object" ? change.value : {};
      const messages = Array.isArray(value.messages) ? value.messages : [];

      if (field === "messages" && messages.length) {
        for (const message of messages) {
          received++;
          const messageId = typeof message?.id === "string" ? message.id : null;
          const { error } = await db.from("integration_events").insert({
            provider: "whatsapp",
            event_type: "inbound_message",
            external_id: messageId,
            status: "received",
            payload: {
              waba_id: entry?.id ?? null,
              phone_number_id: value?.metadata?.phone_number_id ?? null,
              message_type: typeof message?.type === "string" ? message.type : "unknown",
              sender_last4: lastFour(message?.from),
              timestamp: typeof message?.timestamp === "string" ? message.timestamp : null,
            },
          });
          if (!error) saved++;
          else if (error.code === "23505") duplicates++;
          else { failed++; console.error("WhatsApp inbound event insert failed", error.code); }
        }
        continue;
      }

      // Keep only metadata for statuses, history, echoes and app-state events.
      // Status updates intentionally have no external_id: a single message can have
      // multiple status transitions (sent, delivered, read), each of which matters.
      received++;
      const count = Array.isArray(value.messages) ? value.messages.length
        : Array.isArray(value.statuses) ? value.statuses.length
        : Array.isArray(value.history) ? value.history.length
        : null;
      const { error } = await db.from("integration_events").insert({
        provider: "whatsapp",
        event_type: field,
        external_id: null,
        status: "received",
        payload: { waba_id: entry?.id ?? null, field, item_count: count },
      });
      if (!error) saved++;
      else { failed++; console.error("WhatsApp webhook event insert failed", field, error.code); }
    }
  }
  return json({ ok: failed === 0, received, saved, duplicates, failed }, failed ? 500 : 200);
});
