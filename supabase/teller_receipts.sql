-- Teller Module – Official Receipts schema and helpers

create extension if not exists pgcrypto; -- for gen_random_uuid

-- Receipts table (Official Receipts)
create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null,
  receipt_number text not null unique,
  teller_id uuid not null,
  teller_name text not null,
  amount_paid numeric(12,2) not null check (amount_paid >= 0),
  payment_date timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- FK to orders if present
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'orders'
  ) then
    alter table public.receipts
      drop constraint if exists receipts_order_id_fkey,
      add constraint receipts_order_id_fkey
        foreign key (order_id)
        references public.orders(id)
        on delete cascade;
  end if;
exception when others then
  null;
end $$;

-- Updated-at trigger
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_receipts_set_updated_at on public.receipts;
create trigger trg_receipts_set_updated_at
before update on public.receipts
for each row execute function public.set_updated_at();

-- RPC: generate_receipt_number (e.g., OR-YYYYMMDD-xxxxx)
create or replace function public.generate_receipt_number()
returns text language plpgsql as $$
declare
  seq bigint;
  today text := to_char(now(), 'YYYYMMDD');
begin
  select count(*) + 1 into seq from public.receipts where to_char(created_at, 'YYYYMMDD') = today;
  return 'OR-' || today || '-' || lpad(seq::text, 5, '0');
end $$;

-- Basic RLS
alter table public.receipts enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'receipts' and policyname = 'receipts_select_authenticated'
  ) then
    create policy receipts_select_authenticated on public.receipts
      for select to authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'receipts' and policyname = 'receipts_insert_authenticated'
  ) then
    create policy receipts_insert_authenticated on public.receipts
      for insert to authenticated with check (true);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'receipts' and policyname = 'receipts_update_authenticated'
  ) then
    create policy receipts_update_authenticated on public.receipts
      for update to authenticated using (true) with check (true);
  end if;
end $$;

-- Helpful indexes
create index if not exists idx_receipts_created_at on public.receipts(created_at desc);
create index if not exists idx_receipts_order_id on public.receipts(order_id);


