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
