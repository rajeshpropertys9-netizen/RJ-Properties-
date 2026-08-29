-- RJ Properties V8 data model upgrade
alter table public.properties
  add column if not exists plot_area text,
  add column if not exists built_up_area numeric,
  add column if not exists carpet_area numeric,
  add column if not exists occupancy_certificate_status text,
  add column if not exists amenities text,
  add column if not exists map_url text,
  add column if not exists video_url text,
  add column if not exists availability_status text default 'available',
  add column if not exists kitchen_type text,
  add column if not exists utility_room boolean,
  add column if not exists study_room boolean,
  add column if not exists family_lounge boolean,
  add column if not exists media_room boolean,
  add column if not exists powder_room boolean,
  add column if not exists private_terrace boolean,
  add column if not exists living_room boolean,
  add column if not exists dining_area boolean,
  add column if not exists dressing_room boolean,
  add column if not exists guest_bedroom boolean,
  add column if not exists private_garden boolean,
  add column if not exists basement boolean,
  add column if not exists floor_levels text;

update public.properties
set availability_status = coalesce(nullif(availability_status,''), listing_status, status, 'available')
where availability_status is null or availability_status='';

create index if not exists idx_properties_visibility_status on public.properties(visibility, listing_status, availability_status);
create index if not exists idx_buyers_next_followup on public.buyers(next_followup_at);
create index if not exists idx_call_logs_created_at on public.call_logs(created_at desc);

create or replace function public.get_published_properties()
returns table(
  id uuid, title text, property_type text, location text, price numeric, status text,
  description text, media jsonb, community_name text, bhk text, bedrooms integer,
  bathrooms integer, kitchen_type text, pooja_room boolean, balconies integer, servant_room boolean,
  storeroom boolean, utility_room boolean, study_room boolean, family_lounge boolean, media_room boolean, powder_room boolean, private_terrace boolean, living_room boolean, dining_area boolean, dressing_room boolean, guest_bedroom boolean, private_garden boolean, basement boolean, floor_levels text, facing text, area_sqft numeric, built_up_area numeric, carpet_area numeric, plot_area text, uds text,
  floor_number text, construction_age text, car_parking text, block_number text,
  furnishing_status text, permissions_status text, occupancy_certificate boolean,
  maintenance_charges numeric, lift_with_generator boolean, corner_property boolean,
  locality text, payment_mode text, other_charges numeric, community_total_land_area text,
  amenities text, map_url text, video_url text, featured boolean, slug text,
  published_at timestamptz, updated_at timestamptz, primary_media_url text
)
language sql
security definer
set search_path = public, pg_catalog
as $$
  select p.id,p.title,p.property_type,p.location,p.price,p.listing_status,
    p.description,p.media,p.community_name,p.bhk,p.bedrooms,p.bathrooms,p.kitchen_type,p.pooja_room,
    p.balconies,p.servant_room,p.storeroom,p.utility_room,p.study_room,p.family_lounge,p.media_room,p.powder_room,p.private_terrace,p.living_room,p.dining_area,p.dressing_room,p.guest_bedroom,p.private_garden,p.basement,p.floor_levels,p.facing,p.area_sqft,p.built_up_area,p.carpet_area,p.plot_area,p.uds,
    p.floor_number,p.construction_age,p.car_parking,p.block_number,p.furnishing_status,
    p.permissions_status,p.occupancy_certificate,p.maintenance_charges,p.lift_with_generator,
    p.corner_property,p.locality,p.payment_mode,p.other_charges,p.community_total_land_area,
    p.amenities,p.map_url,p.video_url,p.featured,p.slug,p.published_at,p.updated_at,
    (select pm.storage_path from public.property_media pm where pm.property_id=p.id and pm.is_primary=true order by pm.created_at desc limit 1)
  from public.properties p
  where p.visibility='published'
  order by p.featured desc, p.published_at desc nulls last, p.created_at desc;
$$;

-- Public site-visit request: creates/updates a buyer record from submitted contact details, then creates a visit request.
create or replace function public.create_site_visit_request(
  p_name text,
  p_phone text,
  p_property_id uuid,
  p_visit_date date,
  p_visit_time text default null,
  p_notes text default null
) returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_buyer uuid; v_visit uuid;
begin
  select id into v_buyer from public.buyers where phone=trim(p_phone) order by created_at desc limit 1;
  if v_buyer is null then
    insert into public.buyers(name,phone,source,status,lead_stage,notes)
    values(trim(p_name),trim(p_phone),'website-site-visit','new_lead','site_visit',nullif(trim(p_notes),''))
    returning id into v_buyer;
  else
    update public.buyers set name=coalesce(nullif(trim(p_name),''),name), notes=coalesce(nullif(trim(p_notes),''),notes), last_contacted_at=now() where id=v_buyer;
  end if;
  insert into public.site_visits(buyer_id,property_id,visit_date,visit_time,status,notes)
  values(v_buyer,p_property_id,p_visit_date,nullif(trim(p_visit_time),''),'requested',nullif(trim(p_notes),''))
  returning id into v_visit;
  return v_visit;
end;
$$;

-- Buyer/property matching for the private CRM. Uses available/published properties and scores type, BHK and location.
create or replace function public.match_buyer_properties(p_buyer_id uuid)
returns table(property_id uuid,title text,property_type text,location text,bhk text,price numeric,listing_status text,match_score integer,match_reason text)
language sql
security definer
set search_path = public, pg_catalog
as $$
with b as (select * from public.buyers where id=p_buyer_id)
select p.id,p.title,p.property_type,p.location,p.bhk,p.price,p.listing_status,
  (case when b.preferred_property_type is not null and lower(p.property_type)=lower(b.preferred_property_type) then 30 else 0 end
   + case when b.preferred_bhk is not null and lower(p.bhk)=lower(b.preferred_bhk) then 30 else 0 end
   + case when b.preferred_locations is not null and lower(p.location) like '%'||lower(b.preferred_locations)||'%' then 30 else 0 end
   + case when p.visibility='published' and coalesce(p.listing_status,p.status)='available' then 10 else 0 end) as match_score,
  concat_ws(', ',
    case when b.preferred_property_type is not null and lower(p.property_type)=lower(b.preferred_property_type) then 'Property type' end,
    case when b.preferred_bhk is not null and lower(p.bhk)=lower(b.preferred_bhk) then 'BHK' end,
    case when b.preferred_locations is not null and lower(p.location) like '%'||lower(b.preferred_locations)||'%' then 'Location' end,
    case when p.visibility='published' and coalesce(p.listing_status,p.status)='available' then 'Available' end
  ) as match_reason
from public.properties p cross join b
where p.visibility='published' and coalesce(p.listing_status,p.status)='available'
order by match_score desc,p.featured desc,p.updated_at desc
limit 30;
$$;

revoke all on function public.match_buyer_properties(uuid) from public, anon, authenticated;
revoke all on function public.get_published_properties() from public, anon, authenticated;
grant execute on function public.get_published_properties() to anon, authenticated;
revoke all on function public.create_site_visit_request(text,text,uuid,date,text,text) from public;
grant execute on function public.create_site_visit_request(text,text,uuid,date,text,text) to anon, authenticated;
