# RJ Properties CRM V8 — Project Lock & Handover

**Lock date:** 12 November 2026 (IST)  
**Repository:** https://github.com/rajeshpropertys9-netizen/RJ-Properties-  
**Locked baseline commit:** `d6147bb993e305dfb3212bdc20a1bc898288852d`  
**Baseline branch:** `main`

## 1. Lock rule

This document records the current project baseline so future work continues from the existing implementation instead of rebuilding completed features.

- Do not restart the project or recreate existing modules.
- Do not replace working pages, layouts, database tables, functions, branding, or existing records without explicit approval.
- Before every future change: inspect the current repository code, relevant Supabase schema/functions, and current data dependencies.
- Make the smallest incremental change that meets the new request.
- Preserve existing data and backward compatibility. Prefer additive migrations; never drop or overwrite existing data without explicit approval and a verified backup.
- After a change, test the affected workflow and record the result here.
- This is a project baseline lock, not a GitHub branch-protection setting or a claim that production deployment has been verified.

## 2. Existing V8 project baseline

The repository already contains the public property website and private CRM foundation. Existing documented modules include:

- Public website: home, property catalogue, property detail, sell-property intake, buyer enquiry, site-visit enquiry, call/WhatsApp actions, version history.
- Private CRM protected by Supabase Auth: dashboard, buyers, owners, properties, enquiries, follow-ups, site visits and call logs.
- Property management with add/edit, photo upload, main-photo selection/removal, and YouTube/Instagram video-link handling.
- Quick Call Capture for buyer/owner/consultant/other contacts, call notes and supported browser speech-to-text.
- Buyer-to-property matching through the existing matching RPC/API.
- WhatsApp property sharing with buyer/property share-history and repeat-share protection/confirmed resend.
- Existing private owner data handling and existing Supabase security controls.
- Existing property detail fields, filters, published-property catalogue and site-visit request flow.

The files `readme.txt`, `FINAL_QA_V8.3.txt`, and `FINAL_QA_V8.4.txt` remain project reference documents. They are historical QA/build notes; inspect the live code and schema before relying on any detail.

## 3. Buyer self-registration — current implementation

Public form:
- `buyer-requirement.html`
- Public URL: https://rajeshpropertys9-netizen.github.io/RJ-Properties-/buyer-requirement.html

The form currently captures:
- Name and mobile/WhatsApp number
- Property type and preferred location
- Budget
- Land/plot area
- Facing
- Property age (new/resale/under construction/any)
- Payment mode
- Buying timeline
- Additional requirements / notes

Submission path:
- Public form calls Supabase Edge Function `buyer-self-registration`.
- Edge Function is active (version 5 at lock time) and inserts into the existing `buyers` table.
- Self-registered records are marked `pending_approval`.
- CRM Buyers list provides Edit Buyer and Approve actions. Matching is intended after approval.
- The `buyers` table has additive columns for `preferred_facing`, `preferred_property_age`, `preferred_payment_mode`, `preferred_land_area`, and `preferred_buying_timeline`.
- The CRM buyer edit/list workflow includes the additional fields above.

## 4. Buyer duplicate handling — current vs agreed future behaviour

**Current behaviour:** the public registration endpoint detects a matching mobile number and returns an “already registered” response. It does not create a second record through that endpoint and does not automatically merge the new submission into the existing buyer.

**Agreed future requirement (NOT IMPLEMENTED):**
1. Detect a possible existing buyer by normalized mobile number.
2. Show the existing buyer details and the new submission for comparison.
3. Ask the CRM admin to confirm before updating.
4. Preserve the old enquiry/requirement values in history; do not silently overwrite them.
5. Update the existing buyer record only after confirmation; avoid creating an accidental duplicate.
6. Different phone numbers remain separate buyer records, even if names are similar.
7. Do not treat a changed budget/location by itself as proof of a different client.

There are two Rajesh records already present with the same phone number and different budgets (3.5 and 3.3 Cr) in the test data. **Do not merge, delete, approve, or alter these records automatically.** Confirm the correct current requirement with the user first.

## 5. Decisions explicitly retained

- Do not add multi-select property types or a multiple-requirement workflow to the public buyer form at this time. The user chose to note additional requirements during the call and enter them manually in CRM.
- Keep the current buyer form layout and fields unless the user explicitly asks for a change.
- Buying timeline is an information field. Do not automatically change the CRM priority based only on the selected timeline; the advisor retains control of priority.
- Use the user's approved official RJ Properties logo and existing brand styling. Do not invent or substitute another logo.

## 6. Deployment status at lock time — NOT VERIFIED

Latest main commit is `d6147bb993e305dfb3212bdc20a1bc898288852d`.

At the time this lock record was written:
- GitHub Actions workflow `Deploy RJ Properties to GitHub Pages` for the latest commit was still **queued**: https://github.com/rajeshpropertys9-netizen/RJ-Properties-/actions/runs/43097810258
- The parallel `pages build and deployment` run for that commit showed **startup_failure**: https://github.com/rajeshpropertys9-netizen/RJ-Properties-/actions/runs/43097810684

Therefore, the latest Buying Timeline update must **not** be described as production-verified until a successful deployment and live-page check are completed. The public form URL exists, but the newest revision's live status was not confirmed at lock time.

## 7. Next work — resume from here

1. Check why the latest GitHub Pages workflow is queued / why the Pages build reports startup failure; do not re-create the website.
2. After successful deployment, test the public buyer form on mobile, including Land/Plot Area and Buying Timeline.
3. Submit one controlled test enquiry and verify the values in CRM/Supabase.
4. Verify CRM Edit Buyer, approval, and matching behaviour without changing existing customer data.
5. Implement the agreed duplicate comparison + admin-confirmed update + enquiry-history design as a separate future task, only after inspecting current schema/API and planning a safe migration.

## 8. Change log

- V8 existing public website and private CRM baseline retained.
- Buyer self-registration form added.
- Buyer form land/plot area added and wired to database + CRM edit/list.
- Buyer buying timeline added and wired to database + CRM edit/list.
- Buyer approval flow and pending-approval handling added.
- Project lock/handover record created at the commit stated above.

---
**Instruction for future sessions:** Read this file first, then inspect the actual current code/database before making changes. Continue from the locked baseline; do not repeat completed work.

## 9. Buyer–property matching improvement (implemented; deployment verification pending)

The buyer matching RPC `public.match_buyer_properties(uuid)` and CRM Match & Share results were incrementally updated.

- Results are grouped into **Within Budget**, **Up to ₹30L Above Budget**, and **Best Location Match — review asking price**.
- For a single budget, properties up to ₹30 lakh above the entered budget are included. For a budget range, the upper end is extended by ₹30 lakh.
- Properties within budget remain eligible; preferred-location filtering remains in place.
- Best Location Match includes published/available inventory matching the buyer's preferred location and property type even when the asking price is more than ₹30 lakh above budget; the price is clearly marked for advisor review.
- A plain numeric budget such as `3.3` is interpreted as Crores, consistent with the CRM's Hyderabad property-budget entry convention. Explicit Lakh/Crore units continue to be parsed.
- Existing share-history checks, duplicate-share blocking, confirmed resend controls, and buyer approval checks remain unchanged.
- Validation passed for the existing Rajesh records: a ₹3.5 Cr Manikonda/Alkapur independent house appears under **Up to ₹30L Above Budget** for a ₹3.3 Cr buyer, and under **Within Budget** for a ₹3.5 Cr buyer. No customer records were changed by these tests.

The GitHub Pages workflow was extended with deployment smoke tests for the public buyer requirement form, land-area and buying-timeline fields, and the three CRM matching categories. A browser check verifies the form renders without submitting a production enquiry.

**Deployment status:** code and database changes are committed/applied, but the latest GitHub Actions deployment is still queued at the time of this update. Do not call the UI update production-live until the latest workflow succeeds and the deployed CRM is checked.


## 10. Official RJ Properties logo

- The user-confirmed red-and-gold RJ Properties logo artwork with the exact "Find Your Dream House" tagline is the official brand asset.
- Website asset path: `rj-logo.jpg`.
- All public pages and CRM references use this same asset; the old incorrect `rj-logo.png` reference was removed.
- Buyer requirement form logo uses responsive `object-fit: contain` sizing so the full artwork is visible on mobile without cropping or stretching.
- Preserve this exact logo in future RJ Properties project and marketing work; do not substitute a generated logo.


## 11. Buyer requirement form approved visual update

- The approved buyer-form visual direction uses the official RJ Properties red-and-gold identity and a premium property-photo hero.
- The hero uses the existing `hero-property.jpg` project asset behind the original official `rj-logo.jpg`; the logo is displayed at a smaller mobile-safe size to reduce visible upscaling on iPhone screens.
- The redundant tagline above the form title was removed because the official logo already contains “Find Your Dream House”.
- A mobile screenshot review caught that the tagline was still rendering beneath the logo; the duplicate line has now been explicitly removed and the logo URL cache-busted.
- Form structure retains Personal Details, Property Requirements, and Additional Requirements, with the red-and-gold submit action and four trust highlights.
- Existing fields and backend payload remain unchanged, including property type, location, budget, land/plot area, facing, property age, payment mode, buying timeline, and additional requirements.
- Supabase buyer self-registration endpoint, duplicate-number handling, validation, status messages, and CRM buyer records are preserved.
- No database schema, buyer records, or CRM matching behavior is changed by this visual update.
- Deployment must pass the GitHub Pages workflow smoke tests before the new design is described as live.
- Mobile logo sizing is capped at 160 CSS px so the current 320 px logo asset is not enlarged beyond its native retina display width on iPhone; desktop sizing is capped at 190 CSS px.
- Logo and favicon URLs use a fresh cache-busting version; any legacy eyebrow tagline is forcibly hidden so the tagline embedded in the official logo is not duplicated.
- This is a presentation-only correction. Buyer form fields, submission endpoint, duplicate handling, CRM data, and matching logic remain unchanged.

## 12. Buyer form logo display correction

- The buyer form header uses the existing official RJ Properties logo asset only; no substitute/generated brand mark is permitted.
- Logo is centered on a clean white plate with controlled mobile sizing to avoid excessive enlargement of the current repository asset.
- The duplicate standalone “Find Your Dream House” line is suppressed because the tagline is already part of the official logo artwork.
- The logo asset URL is cache-busted so browsers request the current asset reference after deployment.
- This is a presentation-only change. Do not modify buyer form fields, submission payload, Supabase integration, CRM data, or matching behavior as part of this logo fix.
- A true high-resolution asset replacement is still a separate task if a larger source file is added to the repository; do not claim the raster source itself was replaced by this CSS change.


## 13. Buyer form premium reference design

- Match the buyer form visual reference supplied on 12 November 2026: prominent centered RJ Properties logo, property-photo hero, deep-red rounded title banner, gold decorative accents, warm cream background, gold-outline rounded form sections, red section labels, large rounded fields with burgundy icons, bold red submit button, and four trust highlights.
- Maintain responsive two-column fields on wider screens and single-column fields on narrow mobile screens.
- Preserve all existing buyer fields, labels, validation, registration payload, Supabase endpoint, duplicate handling, and CRM integration. The land/plot area and buying timeline fields remain included even if not visible in the reference screenshot crop.
- Presentation-only update; no database schema or CRM records are changed.
- Deployment workflow assertions are updated to verify the new visual markers. Do not call the design live until the GitHub Pages build, smoke tests, and form checks all pass.


## 13. Buyer form logo and hero frame aligned to approved reference

- The user confirmed the supplied full-page reference as the visual target for the logo and header frame.
- The official logo is centered directly in the hero artwork without a separate white card, border, or drop shadow; its white JPEG background blends into the light hero using multiply blending.
- The scenic property hero remains full-width with a softened light overlay, red/gold framing accents, and the existing red-and-gold title treatment.
- Desktop logo width is capped at 460 CSS px; mobile logo width is capped at 350 CSS px / 82vw with a 175px height cap.
- Only buyer-requirement header presentation and matching deployment smoke assertions are changed. Do not change form fields, payload, Supabase integration, buyer records, CRM matching, or other CRM features.
