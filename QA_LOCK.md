# RJ Properties — QA Lock & Completion Ledger

Updated: 2026-11-03
Repository: rajeshpropertys9-netizen/RJ-Properties-
Working branch: integration/whatsapp-coexistence
Production/main: unchanged by this ledger.

## Change-control rules
1. Treat each verified module as locked: do not modify it unless a reproducible bug or explicit requirement is recorded.
2. Before editing, inspect the current implementation and existing commits; do not recreate existing work.
3. Make one focused change per commit and run the relevant check immediately.
4. Keep a short verification note with each fix (what changed, test run, result).
5. Never merge PR #3 or deploy production without the owner's explicit approval.
6. Never use standard WhatsApp number migration or disconnect the existing WhatsApp Business App.

## Verified as of this update
- Supabase project: `bgmlgmdhypmfabyluqvv`.
- Public schema has RLS enabled on all listed application tables, including buyers, owners, properties, enquiries, followups, site_visits, call_logs, and whatsapp_connections.
- Core CRM tables and supporting tables exist: buyers, owners, properties, enquiries, followups, site_visits, call_logs, communities, property_media, property_owner_private, ai_property_matches, integration_events, lead_automation_events, and whatsapp_connections.
- Supabase Edge Functions are ACTIVE: crm-api-v2 v16, external-lead-webhook v9, whatsapp-send v10, whatsapp-cloud-webhook v5, whatsapp-embedded-signup v2.
- `whatsapp_connections` intentionally has RLS enabled with no client policies; table grants are limited to postgres and service_role (verified). Do not add client access policies for token storage.
- Public RPCs flagged by Supabase security advisor are intentionally callable by anon for public enquiry, seller intake, site visit, and published-property catalogue flows. Review function bodies before changing grants.
- GitHub Actions WhatsApp integration checks for commit `2c66649372f7f54854e3881339b8be815dca7a19` completed successfully; Deno formatting and type-check job passed.
- The signup page launch code does NOT include legacy `sessionInfoVersion: "3"`; do not add it unless the current Meta configuration/docs explicitly require it.
- `whatsapp-send` v10 is deployed and re-read from Supabase: it prefers a saved active Coexistence connection token and phone number ID, falls back to legacy secrets, and retains admin auth + explicit recipient consent checks.
- Signup page commit `e0a2a1de1a05fe4ff6ae9a4c34566e8fef5c09f2` adds Embedded Signup v5 `messaging_account_ids` support when resolving the WABA ID; this is on the integration branch only and still needs CI + browser verification.

## Not yet end-to-end verified
- Website forms submitting successfully from a real browser into Supabase.
- CRM create/edit/delete flows across buyers, owners, properties, enquiries, calls, follow-ups, and site visits.
- Buyer-to-property matching correctness with representative budget/location/property cases.
- Mobile Safari behavior and media uploads.
- Meta Embedded Signup completion event, WABA/phone asset discovery, webhook verification, inbound message processing, duplicate handling, history sync, app echo reconciliation, and outbound sends.
- Netlify preview built from the latest branch head.
- Production release and post-release smoke test.

## Current WhatsApp release blockers
1. Confirm the current Meta Embedded Signup configuration supports WhatsApp Business App Coexistence (not standard migration).
2. Confirm required Meta secrets exist in Supabase without exposing them.
3. Verify Meta webhook callback and required WABA subscriptions.
4. Complete a controlled real Coexistence signup and inbound/outbound acceptance test while preserving the existing app and chats.
5. History/contact import and app-echo reconciliation are not implemented by the current webhook; do not describe these as live.

## Completion policy
A module becomes **LOCKED / VERIFIED** only after its code path, permissions, and a relevant test pass are recorded. Existing data is never modified as part of a test. Production remains untouched until explicit approval.
