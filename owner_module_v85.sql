-- RJ Properties CRM V8.5 Owner Module
-- Additive migration: preserves all existing owner and property records.
alter table public.owners
  add column if not exists alternate_phone text,
  add column if not exists whatsapp_phone text,
  add column if not exists address text,
  add column if not exists city text,
  add column if not exists state text,
  add column if not exists pincode text,
  add column if not exists preferred_language text,
  add column if not exists owner_type text,
  add column if not exists decision_maker text,
  add column if not exists contact_person text,
  add column if not exists reference_name text,
  add column if not exists reference_phone text,
  add column if not exists source_listing_id text,
  add column if not exists source_listing_url text,
  add column if not exists first_contacted_at timestamptz,
  add column if not exists last_contacted_at timestamptz,
  add column if not exists next_followup_at timestamptz,
  add column if not exists selling_reason text,
  add column if not exists selling_urgency text,
  add column if not exists minimum_expected_price numeric,
  add column if not exists commission_terms text,
  add column if not exists payment_terms text,
  add column if not exists assigned_to uuid,
  add column if not exists updated_at timestamptz not null default now();

update public.owners
set source_listing_id = coalesce(source_listing_id,
      (regexp_match(coalesce(notes,''), '(?im)^Source Listing ID:\\s*(.+)$'))[1]),
    source_listing_url = coalesce(source_listing_url,
      (regexp_match(coalesce(notes,''), '(?im)^Source Listing URL:\\s*(.+)$'))[1])
where source_listing_id is null or source_listing_url is null;

create table if not exists public.owner_properties (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.owners(id) on delete cascade,
  property_id uuid references public.properties(id) on delete set null,
  title text, property_type text, community_name text, locality text, full_address text,
  survey_plot_number text, flat_villa_number text, facing text,
  land_area_sqyd numeric, built_up_area_sqft numeric, carpet_area_sqft numeric, uds text,
  bhk text, bedrooms integer, bathrooms integer, pooja_room boolean, balconies integer,
  servant_room boolean, storeroom boolean, floor_number text, total_floors text,
  construction_age text, road_width text, car_parking text, furnishing_status text,
  property_condition text, permissions_status text, occupancy_certificate text,
  rera_status text, lrs_brs_status text, property_tax_status text, legal_disputes text,
  expected_price numeric, minimum_price numeric, payment_terms text, other_charges text,
  selling_reason text, selling_urgency text, site_visit_availability text, commission_terms text,
  source_listing_id text, source_listing_url text,
  legal_documents jsonb not null default '{}'::jsonb,
  amenities jsonb not null default '[]'::jsonb,
  notes text, status text not null default 'new',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists owner_properties_owner_id_idx on public.owner_properties(owner_id);
create index if not exists owner_properties_property_id_idx on public.owner_properties(property_id);
create unique index if not exists owner_properties_owner_property_unique
  on public.owner_properties(owner_id, property_id) where property_id is not null;

alter table public.owner_properties enable row level security;
revoke all on public.owner_properties from anon, authenticated;
comment on table public.owner_properties is 'Private owner property inventory and intake records. Access only through admin-authenticated crm-api-v2 Edge Function.';

insert into public.owner_properties(owner_id, property_id, title, status, notes)
select o.id, o.property_id, p.title, coalesce(o.status,'new'),
       'Migrated from legacy owners.property_id link; owner/property relationship preserved.'
from public.owners o left join public.properties p on p.id=o.property_id
where o.property_id is not null
  and not exists (select 1 from public.owner_properties op where op.owner_id=o.id and op.property_id=o.property_id);
