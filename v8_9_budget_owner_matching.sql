-- RJ Properties CRM V8.9: correct mixed lakh/crore budget parsing
-- and include linked owner-origin inventory in private buyer matching.
-- Owner records remain private; only linked, published, available property rows
-- are returned by the admin-only matching function.

create or replace function public.match_buyer_properties(p_buyer_id uuid)
returns table(
  property_id uuid,
  title text,
  property_type text,
  location text,
  bhk text,
  price numeric,
  listing_status text,
  match_score integer,
  match_reason text
)
language sql
security definer
set search_path = public, pg_catalog
as $function$
with buyer as (
  select b.*,
         coalesce(nullif(b.preferred_budget,''), nullif(b.budget,''), '') as budget_text
  from public.buyers b
  where b.id = p_buyer_id
),
budget_token_rows as (
  select b.id as buyer_id,
         (m.parts[1])::numeric *
         case when lower(m.parts[2]) in ('lakh','lakhs','lac','lacs','l') then 0.01 else 1 end as amount_cr
  from buyer b
  cross join lateral regexp_matches(
    b.budget_text,
    '([0-9]+(?:[.][0-9]+)?)\s*(crores?|cr|lakhs?|lacs?|lac|l)\b',
    'gi'
  ) as m(parts)
),
budget_tokens as (
  select buyer_id, min(amount_cr) as budget_min, max(amount_cr) as budget_max, count(*) as token_count
  from budget_token_rows
  group by buyer_id
),
budget_base as (
  select b.*,
         coalesce(t.budget_min, nullif((regexp_match(b.budget_text, '^[[:space:]]*₹?[[:space:]]*([0-9]+(?:[.][0-9]+)?)[[:space:]]*$'))[1], '')::numeric) as parsed_min,
         coalesce(t.budget_max, nullif((regexp_match(b.budget_text, '^[[:space:]]*₹?[[:space:]]*([0-9]+(?:[.][0-9]+)?)[[:space:]]*$'))[1], '')::numeric) as parsed_max,
         coalesce(t.token_count, case when b.budget_text ~ '^[[:space:]]*₹?[[:space:]]*[0-9]+([.][0-9]+)?[[:space:]]*$' then 1 else 0 end) as token_count,
         (b.budget_text ~* '(\mto\M|[-–])') as has_range_separator
  from buyer b
  left join budget_tokens t on t.buyer_id = b.id
),
budget as (
  select bb.*,
         (bb.token_count >= 2 and bb.has_range_separator) as has_range,
         (bb.token_count >= 1) as has_supported_budget,
         case when bb.token_count >= 2 and bb.has_range_separator then bb.parsed_min else null end as budget_min,
         case when bb.token_count >= 2 and bb.has_range_separator then bb.parsed_max else null end as budget_max,
         case when not (bb.token_count >= 2 and bb.has_range_separator) then bb.parsed_max else null end as budget_single
  from budget_base bb
),
inventory as (
  select p.*,
         case when p.price::numeric > 1000 then p.price::numeric / 10000000.0 else p.price::numeric end as price_cr,
         (
           coalesce(p.inventory_source,'') = 'owner_crm'
           or exists(select 1 from public.owner_properties op where op.property_id = p.id)
         ) as is_owner_inventory
  from public.properties p
  where p.visibility = 'published'
    and coalesce(p.listing_status,p.status) = 'available'
),
candidates as (
  select p.*,
         (b.preferred_locations is not null and btrim(b.preferred_locations) <> '' and exists(
           select 1 from regexp_split_to_table(b.preferred_locations, ',') l
           where lower(coalesce(p.location,'')) like '%' || lower(trim(l)) || '%'
         )) as location_match,
         (b.preferred_property_type is not null and lower(coalesce(p.property_type,'')) = lower(b.preferred_property_type)) as type_match,
         (b.preferred_bhk is not null and lower(b.preferred_bhk) <> 'any' and lower(coalesce(p.bhk,'')) = lower(b.preferred_bhk)) as bhk_match,
         case
           when b.has_supported_budget and b.has_range and b.budget_min is not null and b.budget_max is not null
             then p.price_cr between b.budget_min and b.budget_max
           when b.has_supported_budget and not b.has_range and b.budget_single is not null
             then p.price_cr <= b.budget_single
           else false
         end as within_budget,
         case
           when b.has_supported_budget and b.has_range and b.budget_max is not null
             then p.price_cr > b.budget_max and p.price_cr <= b.budget_max + 0.30
           when b.has_supported_budget and not b.has_range and b.budget_single is not null
             then p.price_cr > b.budget_single and p.price_cr <= b.budget_single + 0.30
           else false
         end as slightly_above_budget,
         b.preferred_locations
  from inventory p
  cross join budget b
),
categorized as (
  select c.*,
         case
           when within_budget then 'Within Budget'
           when slightly_above_budget then 'Up to ₹30L Above Budget'
           when location_match and type_match then 'Best Location Match'
           when is_owner_inventory then 'Owner Inventory — Review Location / Budget'
           else null
         end as match_category
  from candidates c
  where preferred_locations is null
     or btrim(preferred_locations) = ''
     or location_match
     or is_owner_inventory
)
select p.id, p.title, p.property_type, p.location, p.bhk, p.price, p.listing_status,
       greatest(0, least(100,
         (case when p.type_match then 25 else 0 end) +
         (case when p.bhk_match then 25 else 0 end) +
         (case when p.location_match then 25 else 0 end) +
         (case when p.within_budget then 25 when p.slightly_above_budget then 15 else 5 end)
       ))::integer as match_score,
       concat_ws(', ',
         p.match_category,
         case when p.is_owner_inventory then 'Owner inventory' end,
         case when p.type_match then 'Property type' end,
         case when p.bhk_match then 'BHK' when p.preferred_locations is not null then 'BHK needs review' end,
         case when p.location_match then 'Preferred location'
              when p.is_owner_inventory then 'Location needs review' end,
         case when p.within_budget then 'Within budget'
              when p.slightly_above_budget then 'Up to ₹30 lakh above budget'
              when p.match_category in ('Best Location Match','Owner Inventory — Review Location / Budget') then 'Price needs review' end,
         'Available'
       ) as match_reason
from categorized p
where p.match_category is not null
order by case p.match_category
           when 'Within Budget' then 1
           when 'Up to ₹30L Above Budget' then 2
           when 'Best Location Match' then 3
           else 4
         end,
         match_score desc, p.featured desc, p.updated_at desc
limit 30;
$function$;

revoke all on function public.match_buyer_properties(uuid) from public, anon, authenticated;
grant execute on function public.match_buyer_properties(uuid) to service_role;
