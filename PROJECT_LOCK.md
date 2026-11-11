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
