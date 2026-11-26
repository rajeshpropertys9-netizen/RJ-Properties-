-- Applied to production Supabase on 2026-11-26 as migration tighten_budget_matching_and_surface_owner_inventory.
-- This is the matching RPC definition retained with the CRM source for reproducibility.
CREATE OR REPLACE FUNCTION public.match_buyer_properties(p_buyer_id uuid)
 RETURNS TABLE(property_id uuid, title text, property_type text, location text, bhk text, price numeric, listing_status text, match_score integer, match_reason text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
with buyer as (
 select b.*,coalesce(nullif(b.preferred_budget,''),nullif(b.budget,''),'') as budget_text
 from public.buyers b where b.id=p_buyer_id
),
budget_token_rows as (
 select b.id as buyer_id,(m.parts[1])::numeric*
 case when lower(m.parts[2]) in ('lakh','lakhs','lac','lacs','l') then 0.01 else 1 end as amount_cr
 from buyer b
 cross join lateral regexp_matches(b.budget_text,'([0-9]+(?:[.][0-9]+)?)\s*(crores?|cr|lakhs?|lacs?|lac|l)\y','gi') as m(parts)
),
budget_tokens as (
 select buyer_id,min(amount_cr) as budget_min,max(amount_cr) as budget_max,count(*) as token_count
 from budget_token_rows group by buyer_id
),
budget_base as (
 select b.*,
 coalesce(t.budget_min,nullif((regexp_match(b.budget_text,'^[[:space:]]*₹?[[:space:]]*([0-9]+(?:[.][0-9]+)?)[[:space:]]*$'))[1],'')::numeric) as parsed_min,
 coalesce(t.budget_max,nullif((regexp_match(b.budget_text,'^[[:space:]]*₹?[[:space:]]*([0-9]+(?:[.][0-9]+)?)[[:space:]]*$'))[1],'')::numeric) as parsed_max,
 coalesce(t.token_count,case when b.budget_text ~ '^[[:space:]]*₹?[[:space:]]*[0-9]+([.][0-9]+)?[[:space:]]*$' then 1 else 0 end) as token_count,
 (b.budget_text ~* '(\mto\M|[-–])') as has_range_separator
 from buyer b left join budget_tokens t on t.buyer_id=b.id
),
budget as (
 select bb.*,(bb.token_count>=2 and bb.has_range_separator) as has_range,(bb.token_count>=1) as has_supported_budget,
 case when bb.token_count>=2 and bb.has_range_separator then bb.parsed_min end as budget_min,
 case when bb.token_count>=2 and bb.has_range_separator then bb.parsed_max end as budget_max,
 case when not (bb.token_count>=2 and bb.has_range_separator) then bb.parsed_max end as budget_single
 from budget_base bb
),
public_inventory as (
 select p.id as property_id,p.title,p.property_type,coalesce(nullif(p.location,''),p.locality) as location,
 p.bhk,p.price,p.listing_status,p.featured,p.updated_at,
 (coalesce(p.inventory_source,'')='owner_crm' or exists(select 1 from public.owner_properties op where op.property_id=p.id)) as is_owner_inventory,
 case when p.price::numeric>1000 then p.price::numeric/10000000.0 else p.price::numeric end as price_cr
 from public.properties p
 where p.visibility='published' and coalesce(p.listing_status,p.status)='available'
),
private_owner_inventory as (
 select op.property_id,coalesce(nullif(op.title,''),op.property_type,'Owner Property') as title,
 op.property_type,op.locality as location,op.bhk,coalesce(op.expected_price,op.minimum_price) as price,
 'owner_private'::text as listing_status,false as featured,op.updated_at,true as is_owner_inventory,
 coalesce(op.expected_price,op.minimum_price) as price_cr
 from public.owner_properties op
 left join public.properties linked on linked.id=op.property_id
 where coalesce(op.status,'new') not in ('sold','inactive','deleted','archived')
 and (op.property_id is null or linked.id is null or linked.visibility is distinct from 'published'
      or coalesce(linked.listing_status,linked.status)<>'available')
),
inventory as (select * from public_inventory union all select * from private_owner_inventory),
candidates as (
 select p.*,
 (b.preferred_locations is not null and btrim(b.preferred_locations)<>'' and exists(
   select 1 from regexp_split_to_table(b.preferred_locations,',') l
   where lower(coalesce(p.location,'')) like '%'||lower(trim(l))||'%'
 )) as location_match,
 (b.preferred_property_type is not null and lower(coalesce(p.property_type,''))=lower(b.preferred_property_type)) as type_match,
 (b.preferred_bhk is not null and lower(b.preferred_bhk)<>'any' and
  regexp_replace(lower(coalesce(p.bhk,'')),'[^0-9]','','g')=regexp_replace(lower(b.preferred_bhk),'[^0-9]','','g')) as bhk_match,
 case when b.has_supported_budget and b.has_range and b.budget_min is not null and b.budget_max is not null
      then p.price_cr between b.budget_min and b.budget_max
      when b.has_supported_budget and not b.has_range and b.budget_single is not null
      then p.price_cr<=b.budget_single else false end as within_budget,
 case when b.has_supported_budget and b.has_range and b.budget_max is not null
      then p.price_cr>b.budget_max and p.price_cr<=b.budget_max+0.40
      when b.has_supported_budget and not b.has_range and b.budget_single is not null
      then p.price_cr>b.budget_single and p.price_cr<=b.budget_single+0.40 else false end as slightly_above_budget,
 b.preferred_locations,b.has_supported_budget
 from inventory p cross join budget b
),
categorized as (
 select c.*,case
  when is_owner_inventory and within_budget then 'Owner Inventory — Within Budget'
  when is_owner_inventory and slightly_above_budget then 'Owner Inventory — Up to ₹40L Above Budget'
  when within_budget then 'Within Budget'
  when slightly_above_budget then 'Up to ₹40L Above Budget'
  when is_owner_inventory then 'Owner Inventory — Review Location / Budget'
  when not has_supported_budget and location_match and type_match then 'Best Location Match — Budget Not Specified'
  else null end as match_category
 from candidates c
 where is_owner_inventory or (
  (preferred_locations is null or btrim(preferred_locations)='' or location_match)
  and (not has_supported_budget or within_budget or slightly_above_budget)
 )
)
select p.property_id,p.title,p.property_type,p.location,p.bhk,p.price,
 case when p.is_owner_inventory and p.has_supported_budget and not p.within_budget and not p.slightly_above_budget
      then case when p.listing_status='owner_private' then 'owner_private' else 'review_only' end
      else p.listing_status end as listing_status,
 greatest(0,least(100,
  (case when p.type_match then 25 else 0 end)+(case when p.bhk_match then 25 else 0 end)+
  (case when p.location_match then 25 else 0 end)+(case when p.within_budget then 25 when p.slightly_above_budget then 15 else 0 end)
 ))::integer as match_score,
 concat_ws(', ',p.match_category,
  case when p.is_owner_inventory then 'Owner inventory' end,
  case when p.type_match then 'Property type' end,
  case when p.bhk_match then 'BHK' when p.preferred_locations is not null then 'BHK needs review' end,
  case when p.location_match then 'Preferred location' when p.is_owner_inventory then 'Location needs review' end,
  case when p.within_budget then 'Within budget' when p.slightly_above_budget then 'Up to ₹40 lakh above budget'
       when p.match_category like 'Owner Inventory%' then 'Price / availability needs review'
       when p.match_category='Best Location Match — Budget Not Specified' then 'Budget not specified' end,
  case when p.listing_status='owner_private' then 'Not published — private owner intake'
       when p.listing_status='review_only' then 'Do not share until budget reviewed' else 'Available' end
 ) as match_reason
from categorized p where p.match_category is not null
order by
 case when p.match_category like 'Owner Inventory — Within Budget%' then 1
      when p.match_category like 'Within Budget%' then 2
      when p.match_category like 'Owner Inventory — Up to%' then 3
      when p.match_category like 'Up to ₹40L Above Budget%' then 4
      when p.match_category like 'Owner Inventory%' then 5 else 6 end,
 (case when p.type_match then 25 else 0 end)+(case when p.bhk_match then 25 else 0 end)+
 (case when p.location_match then 25 else 0 end)+(case when p.within_budget then 25 when p.slightly_above_budget then 15 else 0 end) desc,
 p.featured desc,p.updated_at desc
limit 50;
$function$

