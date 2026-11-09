-- RJ Properties CRM V8: buyer-wise WhatsApp inventory share history
-- Applied to Supabase production via migration buyer_property_whatsapp_share_history.
create table if not exists public.property_share_history (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.buyers(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  shared_by uuid not null references auth.users(id),
  share_status text not null default 'composer_opened'
    check (share_status in ('composer_opened','sent_confirmed')),
  share_count integer not null default 1 check (share_count > 0),
  last_shared_at timestamptz not null default now(),
  last_confirmed_at timestamptz,
  property_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (buyer_id, property_id)
);
create index if not exists idx_property_share_history_buyer
  on public.property_share_history(buyer_id, last_shared_at desc);
create index if not exists idx_property_share_history_property
  on public.property_share_history(property_id);
alter table public.property_share_history enable row level security;
revoke all on public.property_share_history from anon, authenticated;
comment on table public.property_share_history is
  'Private CRM buyer-property WhatsApp sharing history. Access only through admin-verified Edge Function.';
