# RJ Properties — WhatsApp Business App Coexistence

## Safety rule
Do not use the standard WhatsApp Manager **Add phone number** flow for the existing RJ Properties WhatsApp Business App number. Do not disconnect the number or migrate it to API-only mode. The required onboarding is Meta Embedded Signup with the WhatsApp Business App onboarding / Coexistence path.

## Current verified project state
- Existing public website and CRM are in the `main` branch (V8.4).
- Supabase project has an existing `whatsapp-send` function (version 6); it is not evidence that the actual business number is connected.
- A dedicated `whatsapp-cloud-webhook` Edge Function has been deployed. It verifies Meta's `X-Hub-Signature-256`, handles Meta's GET webhook challenge, and records WhatsApp webhook change events in `integration_events`.
- The function is intentionally separate from `external-lead-webhook`; existing Meta lead integrations are not overwritten.

## Supabase secrets required
Set these in Supabase Dashboard → Edge Functions → Secrets:
- `META_APP_SECRET`: App Secret from the RJ Properties Meta Developer app.
- `META_WHATSAPP_VERIFY_TOKEN`: a new, long random string chosen by the owner. Use the exact same value in Meta webhook configuration.

Webhook callback URL:
`https://bgmlgmdhypmfabyluqvv.supabase.co/functions/v1/whatsapp-cloud-webhook`

Subscribe the WhatsApp Business Account webhook fields required for coexistence:
- `messages`
- `history`
- `smb_app_state_sync`
- `smb_message_echoes`
Also keep any existing account update / message status subscriptions enabled as applicable.

## Meta configuration still required
1. In Meta for Developers, configure Facebook Login for Business / WhatsApp Embedded Signup for the RJ Properties app.
2. Ensure the configuration supports WhatsApp Business App onboarding (Coexistence), not standard phone-number migration. For the applicable Embedded Signup version, use Meta's documented WhatsApp Business App onboarding feature option (`whatsapp_business_app_onboarding`) in the launch configuration.
3. Complete App Review and required Advanced Access / Tech Provider prerequisites if Meta requires them for the intended production use.
4. Set the Meta webhook callback URL above and verify it using the exact verify token.
5. Subscribe the app to the WhatsApp Business Account webhook fields listed above.
6. Complete the Embedded Signup as the Business Portfolio admin. Do not share OTPs or access tokens in chat.

## Meta app identifiers captured
- Meta App ID: `1084120231126076`
- Facebook Login for Business Configuration ID: `897611586679448`
- Configuration template: WhatsApp Embedded Signup Configuration With 60 Expiration Token
- Login variation: WhatsApp Embedded Signup
- Token type: System-user access token; template states 60-day expiration
- Configuration created successfully in Meta for Developers (user screenshot confirmation).

These identifiers are configuration metadata, not credentials. The App Secret and any access token must remain in secure secrets storage and must never be committed to GitHub or browser code.

## Values needed before enabling the signup button
The Meta App ID and Facebook Login for Business Configuration ID have now been captured above. They can be used as public Embedded Signup configuration identifiers in the frontend integration. Never put the App Secret or access tokens in browser code. The user-facing signup flow must remain disabled until the Meta Coexistence onboarding path and app prerequisites are confirmed.

## Important limitations
- A webhook endpoint being deployed does not mean Meta is connected or sending events yet.
- Coexistence eligibility is decided by Meta and may require a supported onboarding setup, current WhatsApp Business App version, and active account usage.
- Do not claim message history/contact sync, inbound CRM lead creation, or outbound messaging is live until a real, consented end-to-end test proves it.
- Never log access tokens, OTPs, full phone numbers, or message bodies unnecessarily.


## Implementation checkpoint — 1 November 2026

### Confirmed current backend behavior
- The deployed `whatsapp-cloud-webhook` function is version 1 with JWT verification disabled (required for Meta callbacks). It checks the GET challenge against `META_WHATSAPP_VERIFY_TOKEN`, validates POST requests with `X-Hub-Signature-256` using `META_APP_SECRET`, and writes each received change into `integration_events`.
- The feature-branch webhook validates Meta signatures and stores minimal event metadata. For each unique inbound message it now attempts to find/create a buyer and create a linked CRM enquiry; the event is marked `processed` or `crm_error`. It does not yet import historical chats/contacts, synchronize app echoes into CRM, or send automatic replies. This feature-branch code is not deployed to production.
- The two webhook secrets are not confirmed as configured. Until they are securely set, webhook verification and signed event processing cannot be considered operational.
- The existing `whatsapp-send` Edge Function is separate and must not be treated as proof that the real RJ Properties number is connected.

### Embedded Signup version caution
- The configuration was created from Meta's “WhatsApp Embedded Signup Configuration With 60 Expiration Token” template. Creation success alone does not prove the Coexistence flow is enabled.
- Meta's Embedded Signup v2/v3 deprecation date was 15 October 2026. Treat a newly created configuration as a v4 configuration unless Meta's current dashboard explicitly indicates otherwise; do not ship legacy v2/v3 launch parameters by assumption.
- Before enabling any customer-facing Connect button, verify in Meta's current Embedded Signup configuration/builder that the WhatsApp Business App onboarding / Coexistence experience is actually available for this app. If the flow only presents standard WABA/phone registration, stop; never proceed with the existing app number.
- Coexistence documentation requires the webhook topics `history`, `smb_app_state_sync`, and `smb_message_echoes` in addition to normal message/status topics. History synchronization must be completed within 24 hours of successful onboarding. Keep the WhatsApp Business App active during synchronization.

### Remaining blockers — no production activation yet
1. Securely set `META_APP_SECRET` and a newly generated `META_WHATSAPP_VERIFY_TOKEN` in Supabase Edge Function secrets. Do not put either value in GitHub, frontend JavaScript, or chat.
2. Verify the webhook callback in Meta and subscribe the required WABA fields.
3. Confirm the Meta app's Tech Provider / Solution Partner eligibility, App Review, and Advanced Access requirements for the intended onboarding flow.
4. Implement and test the current supported Embedded Signup version and secure server-side code exchange. Do not store temporary or long-lived access tokens in logs or event payloads.
5. Complete automated tests and a controlled test-environment verification for inbound buyer/enquiry creation, duplicate delivery, database failures, and privacy handling. History/contact import and app-echo reconciliation remain separate work.
6. Run a real end-to-end Coexistence test with the owner, verifying that the existing WhatsApp Business App still works and that old chats/customers remain available. Do not merge to production before this test.

### Current safety gate
The existing RJ Properties number must remain connected to the WhatsApp Business App. Do not use the standard “Add phone number” / API-only migration flow. Do not expose a live signup button until all blockers above are cleared.


### Feature-branch implementation update — 1 November 2026
- Inbound `messages` notifications now use the WhatsApp message ID as an idempotency key in `integration_events.external_id`.
- The handler extracts text/captions (or a safe media placeholder), looks up an exact matching buyer phone, creates a buyer only when no exact match exists, then creates a linked enquiry with source `whatsapp`.
- The event stores only minimal sender metadata; the message content and full sender phone are placed in the CRM enquiry/buyer records because they are needed for lead follow-up.
- This code is committed only to `integration/whatsapp-coexistence` and is not deployed. Automated tests and a real Meta Coexistence event are still required before production use.


### Automated checks
- Added GitHub Actions workflow at `.github/workflows/whatsapp-webhook-checks.yml`.
- On matching branch pushes and pull requests it installs Deno and runs `deno fmt --check` plus `deno check` against the webhook entrypoint.
- A workflow result has not yet been observed; do not treat the code as passing until GitHub Actions reports success.


### Embedded Signup implementation added to the feature branch
- Admin-only page: `whatsapp-connect.html`. It signs in through the existing Supabase Auth project, then launches Meta Embedded Signup with configuration ID `897611586679448` and the Coexistence selector `whatsapp_business_app_onboarding`.
- The page listens for Meta's `WA_EMBEDDED_SIGNUP` completion event and pairs the one-time authorization code with the WABA ID.
- Server endpoint: `supabase/functions/whatsapp-embedded-signup/index.ts`. It verifies the logged-in Supabase user is in `admin_users`, exchanges the code server-side using `META_APP_SECRET`, discovers the phone-number asset, and stores the token in a server-only table. The token is never returned to the browser.
- Migration: `supabase/migrations/202611010001_whatsapp_connections.sql`. It creates a private table with RLS enabled and no anon/authenticated grants.
- Required secrets for the new endpoint: `META_APP_SECRET`, plus the Supabase-provided `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`. The App ID is configured in the function as the known public app ID; Graph version defaults to `v26.0`.
- The migration and endpoint must be deployed/applied only after review. No migration or deployment has been run on the live Supabase project.
- Admin page URL after feature branch deployment: `/whatsapp-connect.html`. It is not linked from the public website or the existing CRM navigation.
- The page's Meta popup is the only place where the owner should enter any verification code. Never send OTPs in ChatGPT.


## Live backend checkpoint — 1 November 2026 (verified)

- Supabase migration `20261101113004_whatsapp_connections` was applied to project `bgmlgmdhypmfabyluqvv`; `public.whatsapp_connections` exists and RLS is enabled.
- Supabase Edge Function `whatsapp-embedded-signup` is ACTIVE at version 2 with JWT verification enabled. It checks Supabase admin membership, exchanges the Meta one-time code server-side, discovers the WABA phone asset, stores the returned token server-side, and attempts `POST /{WABA_ID}/subscribed_apps`. A successful signup response reports `subscribed_pending_verification`; a failed subscription is returned as `pending_subscription` with a warning.
- Supabase Edge Function `whatsapp-cloud-webhook` is ACTIVE at version 5 with JWT verification disabled for Meta callbacks. It verifies GET challenge requests against `META_WHATSAPP_VERIFY_TOKEN`, validates POST signatures using `META_APP_SECRET`, deduplicates inbound messages using WhatsApp message IDs, finds/creates a CRM buyer, and creates a CRM enquiry. It logs coexistence history/contact/app-echo event metadata only; it does not yet import history/contact records or reconcile app-sent echoes into CRM.
- Supabase `whatsapp-send`, `external-lead-webhook`, and `crm-api-v2` were not redeployed as part of this checkpoint.
- GitHub feature branch `integration/whatsapp-coexistence` remains separate from `main`; PR #3 remains unmerged. The public website was not changed.

## Remaining Meta owner actions / acceptance tests

1. In Meta for Developers → RJ Properties app → Webhooks, configure callback URL:
   `https://bgmlgmdhypmfabyluqvv.supabase.co/functions/v1/whatsapp-cloud-webhook`
2. Enter the exact `META_WHATSAPP_VERIFY_TOKEN` value saved in Supabase and verify the callback. Do not post the token in chat.
3. Subscribe the app to the WhatsApp Business Account fields: `messages`, `history`, `smb_app_state_sync`, `smb_message_echoes`, and applicable status/account update fields. The signup backend now also calls WABA `subscribed_apps` after successful authorization.
4. Open the admin-only setup page from the feature branch after it is safely previewed/deployed; sign in with an authorized CRM admin and complete the Meta Coexistence flow. Enter any OTP only in Meta's own popup.
5. Confirm the connected number reports coexistence status (including `is_on_biz_app=true` where available), test a new inbound message, confirm one Buyer and one Enquiry are created, confirm duplicate webhook delivery does not create another enquiry, and verify the WhatsApp Business App still works with existing chats.
6. Test outbound API messaging and 24-hour policy/template behavior separately. Do not claim history/contact sync or app echo mirroring is complete until those processors are implemented and tested.

## Security and release notes

- The connection table has RLS enabled and no anon/authenticated grants; access is intended only through server-side service-role functions. The access token is stored in the server-only database table; it is not returned to the browser or written to GitHub. It is not application-layer encrypted in this implementation, so restrict service-role access and consider adding envelope encryption before broad multi-tenant use.
- The verification token was initially entered in the chat-guided setup; for stronger hygiene, rotate it to a fresh random value in Supabase and update the Meta webhook configuration together before production rollout.
- Do not use standard Add Phone Number / migration. Do not disconnect the existing WhatsApp Business App number.
- PR #3 is not merged. Do not deploy the admin page to the production website or expose its connect button until Meta eligibility, callback verification, and end-to-end tests pass.
