-- RJ Properties V8.0 backend hardening: buyer/property matching + quick-call CRM sync
-- Applied to Supabase production as migration v8_matching_and_call_sync.
-- This file is kept with the package for version history/reproducibility.

create index if not exists idx_buyers_phone on public.buyers(phone);
create index if not exists idx_properties_listing_status on public.properties(listing_status, visibility);

create or replace function public.match_buyer_properties(p_buyer_id uuid)
returns table(property_id uuid,title text,property_type text,location text,bhk text,price numeric,listing_status text,match_score integer,match_reason text)
language sql
security definer
set search_path = public, pg_catalog
as $$
with b as (select * from public.buyers where id=p_buyer_id),
parsed as (
 select b.*,
 nullif((regexp_match(coalesce(b.preferred_budget,b.budget,''), '(?i)([0-9]+(?:\\.[0-9]+)?)\\s*(?:cr|crore|crores)'))[1],'')::numeric budget_single,
 nullif((regexp_match(coalesce(b.preferred_budget,b.budget,''), '(?i)([0-9]+(?:\\.[0-9]+)?)\\s*(?:to|-)\\s*([0-9]+(?:\\.[0-9]+)?)\\s*(?:cr|crore|crores)'))[1],'')::numeric budget_min,
 nullif((regexp_match(coalesce(b.preferred_budget,b.budget,''), '(?i)([0-9]+(?:\\.[0-9]+)?)\\s*(?:to|-)\\s*([0-9]+(?:\\.[0-9]+)?)\\s*(?:cr|crore|crores)'))[2],'')::numeric budget_max
 from b)
select p.id,p.title,p.property_type,p.location,p.bhk,p.price,p.listing_status,
(case when b.preferred_property_type is not null and lower(p.property_type)=lower(b.preferred_property_type) then 25 else 0 end
 +case when b.preferred_bhk is not null and lower(p.bhk)=lower(b.preferred_bhk) then 25 else 0 end
 +case when b.preferred_locations is not null and exists(select 1 from regexp_split_to_table(b.preferred_locations, ',') l where lower(p.location) like '%'||lower(trim(l))||'%') then 25 else 0 end
 +case when b.budget_single is not null and p.price between b.budget_single*0.9 and b.budget_single*1.1 then 15 when b.budget_min is not null and b.budget_max is not null and p.price between b.budget_min and b.budget_max then 15 else 0 end
 +10) match_score,
concat_ws(', ',case when b.preferred_property_type is not null and lower(p.property_type)=lower(b.preferred_property_type) then 'Property type' end,case when b.preferred_bhk is not null and lower(p.bhk)=lower(b.preferred_bhk) then 'BHK' end,case when b.preferred_locations is not null and exists(select 1 from regexp_split_to_table(b.preferred_locations, ',') l where lower(p.location) like '%'||lower(trim(l))||'%') then 'Location' end,case when b.budget_single is not null and p.price between b.budget_single*0.9 and b.budget_single*1.1 then 'Budget' when b.budget_min is not null and b.budget_max is not null and p.price between b.budget_min and b.budget_max then 'Budget' end,'Available') match_reason
from public.properties p cross join parsed b
where p.visibility='published' and coalesce(p.listing_status,p.status)='available'
order by match_score desc,p.featured desc,p.updated_at desc limit 30;
$$;
revoke all on function public.match_buyer_properties(uuid) from public, anon, authenticated;
