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
          const senderDigits = String(message?.from ?? "").replace(/\D/g, "");
          const senderPhone = senderDigits ? "+" + senderDigits : null;
          const messageType = typeof message?.type === "string" ? message.type : "unknown";
          const messageText = messageType === "text" ? String(message?.text?.body ?? "")
            : messageType === "image" ? String(message?.image?.caption ?? "[WhatsApp image]")
            : messageType === "video" ? String(message?.video?.caption ?? "[WhatsApp video]")
            : messageType === "document" ? String(message?.document?.filename ?? "[WhatsApp document]")
            : messageType === "button" ? String(message?.button?.text ?? "[WhatsApp button]")
            : messageType === "interactive" ? String(message?.interactive?.button_reply?.title ??
              message?.interactive?.list_reply?.title ?? "[WhatsApp interaction]")
            : "[WhatsApp " + messageType + " message]";

          const { data: eventRow, error: eventError } = await db.from("integration_events").insert({
            provider: "whatsapp",
            event_type: "inbound_message",
            external_id: messageId,
            status: "received",
            payload: {
              waba_id: entry?.id ?? null,
              phone_number_id: value?.metadata?.phone_number_id ?? null,
              message_type: messageType,
              sender_last4: lastFour(message?.from),
              timestamp: typeof message?.timestamp === "string" ? message.timestamp : null,
            },
          }).select("id").single();

          if (eventError?.code === "23505") { duplicates++; continue; }
          if (eventError || !eventRow) {
            failed++;
            console.error("WhatsApp inbound event insert failed", eventError?.code ?? "no_event_row");
            continue;
          }
          if (!senderPhone) {
            await db.from("integration_events").update({ status: "needs_review" }).eq("id", eventRow.id);
            saved++;
            continue;
          }

          let buyerId: string | null = null;
          const { data: existingBuyer, error: buyerLookupError } = await db
            .from("buyers").select("id").eq("phone", senderPhone).limit(1).maybeSingle();
          if (buyerLookupError) {
            failed++;
            await db.from("integration_events").update({ status: "crm_error", error_message: "Buyer lookup failed" }).eq("id", eventRow.id);
            continue;
          }
          if (existingBuyer?.id) buyerId = existingBuyer.id;
          else {
            const { data: newBuyer, error: buyerInsertError } = await db.from("buyers").insert({
              name: "WhatsApp lead",
              phone: senderPhone,
              source: "whatsapp",
              lead_source: "whatsapp",
              status: "new_lead",
              lead_stage: "new",
            }).select("id").single();
            if (buyerInsertError || !newBuyer?.id) {
              failed++;
              await db.from("integration_events").update({ status: "crm_error", error_message: "Buyer creation failed" }).eq("id", eventRow.id);
              continue;
            }
            buyerId = newBuyer.id;
          }

          const { data: enquiry, error: enquiryError } = await db.from("enquiries").insert({
            buyer_id: buyerId,
            name: "WhatsApp lead",
            phone: senderPhone,
            message: messageText.slice(0, 4000),
            source: "whatsapp",
            status: "new",
            lead_stage: "new",
            notes: messageId ? "WhatsApp message ID: " + messageId : "WhatsApp inbound message",
          }).select("id").single();

          if (enquiryError || !enquiry?.id) {
            failed++;
            await db.from("integration_events").update({ status: "crm_error", lead_id: buyerId, error_message: "Enquiry creation failed" }).eq("id", eventRow.id);
            continue;
          }
          await db.from("integration_events").update({
            status: "processed", lead_id: buyerId, enquiry_id: enquiry.id, processed_at: new Date().toISOString(),
          }).eq("id", eventRow.id);
          saved++;
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
