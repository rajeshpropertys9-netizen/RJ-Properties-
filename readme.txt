RJ PROPERTIES — V8.4 MASTER BUILD
=================================

V7 was preserved as the baseline. V8 upgrades the existing project without redesigning the working V7 hamburger menu or public enquiry flow.

PUBLIC WEBSITE
- Premium RJ Properties homepage
- Properties catalog with filters
- Rich property details: Built-up Area, Carpet Area, Plot/Land Area, UDS, BHK, bedrooms, baths, parking, facing, floor, age, furnishing, permissions, OC status (Obtained/Pending/Not Available/Not Applicable/Not Verified), maintenance, lift/generator, corner, community, amenities, Maps, video, availability and last updated
- WhatsApp + click-to-call
- Schedule Site Visit request
- Sell Property / private owner intake
- Buyer enquiry
- Version History page
- Mobile hamburger menu

PRIVATE CRM — ADMIN
- Secure Supabase Auth login
- Dashboard: Properties, Buyers, Owners, Enquiries, Follow-ups, Site Visits, Calls
- Buyer management
- Owner management
- Property management with full details
- Quick Call Capture for Buyer/Owner/Consultant/Other
- Browser voice-to-text for call notes when supported
- Lead temperature + follow-up date + call outcome
- Call log history
- Buyer → Property matching with type/BHK/location/budget scoring
- Quick Call Capture auto-syncs buyer/owner contact records when name + phone are supplied. Source platform and preferred language are captured in call notes for compatibility.
- Site visit tracking
- Follow-up tracking

SUPABASE
- Existing CRM tables reused
- V8 property fields added: plot_area, amenities, map_url, video_url, availability_status
- Rich published-property RPC
- Site visit request RPC
- Buyer/property matching RPC
- crm-api-v2 upgraded to serve dashboard, CRUD, call logs and matching
- No service-role key is exposed in browser files
- Private CRM remains behind Supabase Auth + admin_users

VOICE / AI REALITY
- Browser voice-to-text is included for fast call-note capture.
- A true AI voice agent or automated WhatsApp Business messaging still requires a provider/API account; V8 does not pretend to activate a paid provider without credentials.

DEPLOYMENT
1. Keep the V7 live site untouched until V8 is verified.
2. Upload the V8 package to the chosen static host.
3. Verify public pages and then verify the private CRM login.
4. Do not publish admin.html as a public discoverable link; keep it protected by Supabase Auth.

VERSION HISTORY
V7: Hamburger menu fix, property catalog/details, WhatsApp and call CTAs, CRM foundation.
V8: Complete property details, site visits, Buyer/Owner CRM, Quick Call Capture, voice-to-text, matching, dashboard and version history.

BACKEND STATUS
- Supabase migration v8_matching_and_call_sync applied.
- crm-api-v2 active version 5.
- V7 live site remains separate and untouched.

Owner sourcing fields: Source platform, source listing ID/URL, call outcome and follow-up are captured in the private CRM; source URL/ID are stored with owner notes for compatibility.\n\nAdvanced room fields: kitchen, pooja, balconies, servant/maid, store, utility, study, family lounge, media/home theatre, powder room, terrace, living, dining, dressing/walk-in, guest bedroom, private garden, basement, and floor/level count.
