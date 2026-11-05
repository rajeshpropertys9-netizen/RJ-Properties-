create table if not exists public.whatsapp_connections (id uuid primary key default gen_random_uuid(), provider text not null default 'whatsapp' check (provider = 'whatsapp'), waba_id text not null unique, phone_number_id text, display_phone_number text, verified_name text, access_token text not null, token_expires_at timestamptz, connection_mode text not null default 'coexistence', status text not null default 'pending_webhook', created_at timestamptz not null default now(), updated_at timestamptz not null default now());
alter table public.whatsapp_connections enable row level security;
revoke all on public.whatsapp_connections from anon, authenticated;
create index if not exists whatsapp_connections_status_idx on public.whatsapp_connections(status);
