-- Gate Collector Module – Clearing Certificates and Activity Logs

create extension if not exists pgcrypto; -- for gen_random_uuid

-- Clearing Certificates table
create table if not exists public.clearing_certificates (
  id uuid primary key default gen_random_uuid(),
  official_receipt_id uuid not null,
  certificate_number text not null unique,
  qr_code text,
  status text not null default 'generated' check (status in ('generated','validated','expired')),
  validated_at timestamptz,
  validated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- FK to receipts if present
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'receipts'
  ) then
    alter table public.clearing_certificates
      drop constraint if exists clearing_certificates_official_receipt_id_fkey,
      add constraint clearing_certificates_official_receipt_id_fkey
        foreign key (official_receipt_id)
        references public.receipts(id)
        on delete cascade;
  end if;
exception when others then
  null;
end $$;

-- Activity Logs table
create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  certificate_id text not null,
  gate_collector_id uuid not null,
  gate_collector_name text not null,
  validation_result text not null check (validation_result in ('success','fail')),
  message text,
  timestamp timestamptz not null default now()
);

-- Updated-at trigger
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_clearing_certificates_set_updated_at on public.clearing_certificates;
create trigger trg_clearing_certificates_set_updated_at
before update on public.clearing_certificates
for each row execute function public.set_updated_at();

-- RPC: generate_certificate_number (e.g., CC-YYYYMMDD-xxxxx)
create or replace function public.generate_certificate_number()
returns text language plpgsql as $$
declare
  seq bigint;
  today text := to_char(now(), 'YYYYMMDD');
begin
  select count(*) + 1 into seq from public.clearing_certificates where to_char(created_at, 'YYYYMMDD') = today;
  return 'CC-' || today || '-' || lpad(seq::text, 5, '0');
end $$;

-- Basic RLS
alter table public.clearing_certificates enable row level security;
alter table public.activity_logs enable row level security;

-- Policies for clearing_certificates
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'clearing_certificates' and policyname = 'clearing_certificates_select_authenticated'
  ) then
    create policy clearing_certificates_select_authenticated on public.clearing_certificates
      for select to authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'clearing_certificates' and policyname = 'clearing_certificates_insert_authenticated'
  ) then
    create policy clearing_certificates_insert_authenticated on public.clearing_certificates
      for insert to authenticated with check (true);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'clearing_certificates' and policyname = 'clearing_certificates_update_authenticated'
  ) then
    create policy clearing_certificates_update_authenticated on public.clearing_certificates
      for update to authenticated using (true) with check (true);
  end if;
end $$;

-- Policies for activity_logs
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'activity_logs' and policyname = 'activity_logs_select_authenticated'
  ) then
    create policy activity_logs_select_authenticated on public.activity_logs
      for select to authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'activity_logs' and policyname = 'activity_logs_insert_authenticated'
  ) then
    create policy activity_logs_insert_authenticated on public.activity_logs
      for insert to authenticated with check (true);
  end if;
end $$;

-- Helpful indexes
create index if not exists idx_clearing_certificates_status_created_at on public.clearing_certificates(status, created_at desc);
create index if not exists idx_clearing_certificates_qr_code on public.clearing_certificates(qr_code);
create index if not exists idx_clearing_certificates_official_receipt_id on public.clearing_certificates(official_receipt_id);

create index if not exists idx_activity_logs_timestamp on public.activity_logs(timestamp desc);
create index if not exists idx_activity_logs_certificate_id on public.activity_logs(certificate_id);
create index if not exists idx_activity_logs_gate_collector_id on public.activity_logs(gate_collector_id);
