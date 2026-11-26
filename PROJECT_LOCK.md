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


## 14. Exact first approved buyer-form preview restored

- The latest user reference explicitly confirms the first compact buyer-form design preview as the target. Keep that visual direction, not the later oversized standalone-logo treatment.
- Use the existing official RJ Properties logo centered over the scenic property hero image; the logo is compact and proportional on mobile (225px max / 56vw) and larger but controlled on desktop (440px max / 54vw).
- Keep the scenic hero background visible on both sides of the logo with a soft warm overlay, followed by the maroon Buyer Requirement Form title, subtitle, and gold/red divider treatment.
- Add the rounded premium outer frame around the page (desktop 24px; mobile 22px) with a subtle border/shadow; no separate white logo card, no duplicated tagline, and no invented or regenerated logo.
- Preserve the three form sections, existing fields, submission flow, duplicate-number handling, Supabase integration, and CRM approval/matching behavior. This update is presentation-only.


## 15. Owner Module V8.5 — implemented 14 November 2026

- Owner profile expanded with primary/alternate/WhatsApp numbers, email, owner type, relationship, decision maker, contact person, preferred language/contact time, complete address, city/state/PIN, source listing ID/URL, references, status, first/last contact dates, next follow-up, selling reason/urgency, minimum expected price, commission/payment terms, and notes.
- One Owner → Multiple Properties is supported through the new private `owner_properties` table. Each owner property can link to an existing CRM property or be captured as an off-market property.
- Each owner property captures property type/title, project/community, locality/address, survey/plot and flat/villa identifiers, facing, land/built-up/carpet area, UDS, BHK/bedrooms/bathrooms/balconies, floor/levels, age, road width, parking, furnishing, condition, permissions, OC, RERA, LRS/BRS, property tax, legal disputes, expected/minimum price, payment terms, selling reason/urgency, site visit availability, commission terms, source listing details, notes, and private legal document URLs (sale deed, link documents, EC, RERA, LRS/BRS, property tax, OC).
- Legacy `owners.property_id` remains in place; existing relationships are copied additively to `owner_properties` where present. Existing owner notes and records are not deleted.
- New table has RLS enabled and direct anon/authenticated grants revoked; access is through the admin-authenticated `crm-api-v2` Edge Function using the service role.
- Database migration `complete_owner_module_v85` applied successfully. `crm-api-v2` deployed as version 18 with owner-property GET/POST/PATCH/DELETE support.
- `admin.html` updated to V8.5; owner list shows linked-property count and supports view/edit. Main inline JavaScript syntax check passed after final room-field and partial-save safeguards.
- Latest owner module UI commit: `fb48ad7b3c88bd295a546df827d8f3646611595c` (browser title/login labels included); migration source committed as `owner_module_v85.sql` (`cfd829e12a46ec031cfef3111c63337e0d2a6997`).
- **Deployment status:** GitHub Pages workflow for this commit was pending at the last check. Do not call the live UI production-verified until the workflow succeeds and the deployed owner form is opened and tested on mobile.
- **Live data validation still required:** create a controlled test owner with two linked properties, edit one property without changing the other, and verify owner/property records remain private. Do not create a fake production owner automatically.


## 16. Buyer form reference restoration — 19 November 2026

- User reconfirmed the supplied full-page Buyer Requirement Form image as the exact visual reference. Treat this image as the approved visual lock; do not make unsolicited layout, logo, colour, spacing, or field-order changes after approval.
- Latest presentation-only update restores the reference styling: compact centered official logo blended over the property hero, maroon title banner with gold accents, cream page, rounded gold-outline sections, burgundy section labels and icons, two-column property fields on wider screens, large red submit button, and four gold line-art trust icons.
- Existing public form fields remain present: name, mobile, property type, location, budget, land/plot area, facing, property age, payment mode, buying timeline, and additional requirements. Narrow mobile widths stack fields for legibility.
- Supabase buyer-self-registration endpoint, payload keys, validation, duplicate-number handling, pending-approval flow, CRM buyer records, and matching are unchanged.
- No database, CRM module, owner records, or property inventory changes were made.
- Latest HTML visual commits: 8c7ac8064bca52da851d2b441e9c26bbd36fa7be and 9914a9f53cd34278422265e77c0f73e9325ad83e.
- The current repository hero image asset is retained and cropped/faded in the header so its embedded lower WhatsApp/location strip does not compete with the form title. This is a best match using the existing asset; the hero photograph is not a pixel-identical replacement for the supplied mockup artwork.
- Deployment status: the GitHub Pages workflow for the latest visual update must succeed before calling the page production-live. Complete a live mobile visual check and form-render smoke test before locking this revision as production-approved.


## 17. Buyer requirement form — new exact full-page reference (23 November 2026)

- The user's latest full-page image explicitly supersedes the prior public buyer-form visual and field arrangement.
- Target layout: official RJ Properties logo integrated into a premium villa/city hero; centered red Buyer Requirement Form banner; bold heading/subheading; cream background; gold-outline rounded sections; three sections titled Personal Details, Property Requirements, Additional Requirements; prominent red Submit Requirements button; four benefit items at the bottom.
- Personal Details: name, mobile/WhatsApp, optional email.
- Property Requirements: property type, preferred location(s), configuration (BHK), budget range.
- Additional Requirements: checkboxes for Gated Community, Ready to Move, Under Construction, RERA Approved, Vastu Compliant, East Facing, North Facing, Flexible (Any), plus optional free-text notes.
- Multiple selected locations are serialized as a comma-separated preferred_locations string. Selected preference checkboxes are retained in the existing additional_requirements/notes field. Email and BHK map to existing buyer-self-registration payload fields.
- The existing Supabase buyer-self-registration endpoint, duplicate-phone detection, pending-approval flow, and CRM buyer records remain in place. No database migration or existing customer record change is part of this UI update.
- This approved field arrangement supersedes the earlier public form fields on the page; CRM's existing extra buyer fields and stored data are not deleted.
- The page and deployment smoke tests have been updated. Do not describe this revision as live until GitHub Pages deploy and smoke/UI checks succeed and the deployed page is visually checked on mobile.


## 18. FINAL LOCK — Buyer Requirement Form reference (24 November 2026)

- The user's supplied full-page RJ Properties Buyer Requirement Form image is the authoritative visual reference and supersedes previous buyer-form styling.
- Header: cream canvas, luxury villa/city hero backdrop, exact official RJ Properties logo, red rounded Buyer Requirement Form title, bold requirement heading, italic supporting line, gold accents.
- Section 1 Personal Details: Name, Mobile / WhatsApp Number, optional Email. Three columns on desktop; stacked fields on mobile.
- Section 2 Property Requirements: Property Type, Preferred Location(s), Configuration (BHK), Budget Range. Two columns on desktop; stacked on mobile.
- Section 3 Additional Requirements: Gated Community, Ready to Move, Under Construction, RERA Approved, Vastu Compliant, East Facing, North Facing, Flexible (Any), and optional Other Requirements text.
- Primary action: prominent red Submit Requirements button.
- Footer benefits in this exact order: Personalised Property Suggestions; Expert Guidance; Site Visit Assistance; End-to-End Support.
- Brand colors and visual language are locked: cream/white background, RJ red/burgundy, gold borders and accents, rounded section cards, clean responsive typography.
- Existing buyer-self-registration endpoint and payload mapping remain. Existing duplicate-number protection, pending-approval workflow, CRM records, and database data must not be deleted or altered as part of design work.
- Multi-location selection remains supported; selected locations are stored in the existing preferred_locations field. Selected checkboxes and optional notes are stored in existing additional_requirements.
- Future changes must preserve this exact layout and visual style unless the user explicitly approves a design change.
- Production verification completed 24 November 2026: GitHub Pages deployment succeeded; live smoke test passed; Playwright mobile-width (390px) buyer form check confirmed email, BHK, budget, multi-location picker, all eight preference checkboxes, and submit button render; LIVE_UI_SMOKE_OK passed. Treat this exact revision as production-locked.


## 19. Buyer Requirement Form — reference-image correction (24 November 2026)

- The user's full-page 1024x1536 reference image is the exact visual target. The live mobile screenshot previously differed: it used the alternate Avni villa image as the mobile hero and the keyed transparent logo appeared washed out.
- Mobile hero background now uses the same `hero-property.jpg` banner as the desktop hero, instead of the alternate Avni villa image.
- The official transparent RJ logo SVG retains its original artwork and now uses a stronger alpha transfer so gold and red details are not washed out against the hero image.
- Mobile logo is enlarged to use up to 90vw and is not height-cropped.
- Keep the exact functional HTML form below the banner. Do not replace it with a flattened image: all form fields, multi-location choices, eight additional requirement checkboxes, submission flow and existing backend mapping must remain functional.
- Keep the approved reference layout: red title pill, bold headline, italic subtitle, cream canvas, red/gold section headers, three-column Personal Details and two-column Property Requirements on desktop, responsive stacked fields on mobile, red submit button, four footer benefits.
- Deployment workflow checks that the mobile hero pseudo-element uses `hero-property.jpg`, the official `rj-logo.jpg` loads at a visible width, and the logo uses full-opacity multiply blending to avoid a white box.
- Production verification completed 24 November 2026: GitHub Pages deployment succeeded; live smoke test passed; Playwright mobile browser test at 390px confirmed the hero pseudo-element loads the property banner, the official logo image loads visibly above 250px with full opacity and multiply blending, all buyer fields and eight preferences render, and the submit button is present without creating a production enquiry. Treat this corrected mobile/desktop header as production-locked.


## 20. Canonical public URL and deployment lock (25 November 2026)

- The only approved GitHub Pages origin for this repository is `https://rajeshpropertys9-netizen.github.io/RJ-Properties-/`.
- The only approved public Buyer Requirement Form URL is `https://rajeshpropertys9-netizen.github.io/RJ-Properties-/buyer-requirement.html`.
- These URLs are derived from the actual GitHub repository owner `rajeshpropertys9-netizen` and repository `RJ-Properties-`. Do not copy or manually retype a similar-looking GitHub username/domain from old WhatsApp messages.
- The WhatsApp screenshot showed a different, misspelled Pages hostname (`rajeshproperties9-netizen.github.io`). That hostname is not the owner of this repository and must not be reused.
- The Pages deployment workflow now has a hard guard: deployment smoke tests fail unless GitHub Pages reports the exact canonical hostname and repository path. The workflow also performs a direct live fetch of `buyer-requirement.html` and checks its form markup.
- All future buyer-form sharing must copy the URL from this section or the canonical link file `PUBLIC_LINKS.md`; do not construct it manually.
- This guard prevents publishing a deployment under the wrong owner/repository URL from being reported as successful. It cannot prevent someone from manually pasting a typo into an external WhatsApp message; always copy the canonical link.
- Visual design, buyer fields, Supabase submission endpoint, existing CRM data and other project functionality remain unchanged by this deployment guard.
- **Status:** repository workflow guard committed; production deployment and live URL verification are pending the resulting GitHub Actions run. Do not claim the permanent fix is production-verified until the workflow succeeds and the canonical Buyer Requirement Form URL opens without a 404.


## 12. V8.9 buyer budget matching and owner inventory correction — 26 November 2026

- Root cause confirmed in the live database for buyer Srinivas goud Etukala: the saved budget is `₹50 Lakhs – ₹1 Crore`, but the prior matching function intentionally included location/type matches at any asking price under **Best Location Match — review asking price**.
- The previous matching function returned public properties priced at ₹2.40 Cr, ₹2.30 Cr, and ₹1.50 Cr for this buyer even though they were outside the budget. This behaviour has been removed for buyers with a supported budget range.
- New matching rule: public inventory must be within the entered budget range or no more than ₹30 lakh above the upper limit, and must meet the preferred location filter when locations are supplied.
- Owner-linked inventory remains visible in a separate owner-inventory group for advisor review even when it is outside budget or not yet published. An owner record that is outside budget is marked review-only and cannot be selected or shared through WhatsApp until reviewed. Unpublished private owner intake is displayed without owner contact details and cannot be shared until published.
- Existing owner/property links, owner contact privacy, buyer records, WhatsApp share history, and resend safeguards are preserved.
- Database migration applied: `tighten_budget_matching_and_surface_owner_inventory`.
- Live RPC verification for Srinivas: ₹2.40 Cr, ₹2.30 Cr and ₹1.50 Cr public listings are no longer returned. The linked owner property “G+1” at ₹1.90 Cr is returned only in the separate review-only owner inventory group.
- CRM UI update committed to group owner inventory separately, put it before other match groups, disable sharing for private/review-only records, and clarify the budget notice.
- GitHub commit: `bdce3009989b754fd4d69ad1c282fd62545e8c52`.
- **Deployment verification pending:** do not call the UI production-live until the current GitHub Pages workflow succeeds and the live CRM is checked on mobile.
