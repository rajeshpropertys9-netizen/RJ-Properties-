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
