-- Collector Module – Orders of Payment schema and helpers

-- Enable required extensions
create extension if not exists pgcrypto; -- for gen_random_uuid

-- Orders table (Orders of Payment)
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  fish_product_id uuid,
  order_number text not null unique,
  collector_id uuid not null,
  collector_name text not null,
  amount numeric(12,2) not null check (amount >= 0),
  quantity integer,
  due_date timestamptz,
  qr_code text,
  status text not null default 'pending' check (status in ('pending','issued','paid')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure due_date column exists (in case of schema migration issues)
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'orders' and column_name = 'due_date'
  ) then
    alter table public.orders add column due_date timestamptz;
  end if;
exception when others then
  -- ignore if column already exists or other issues
  null;
end $$;

-- Optional FK if referenced table exists
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'fish_products'
  ) then
    alter table public.orders
      drop constraint if exists orders_fish_product_id_fkey,
      add constraint orders_fish_product_id_fkey
        foreign key (fish_product_id)
        references public.fish_products(id)
        on delete set null;
  end if;
exception when others then
  -- ignore if fish_products doesn't have id or incompatible type
  null;
end $$;

-- Updated-at trigger
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_orders_set_updated_at on public.orders;
create trigger trg_orders_set_updated_at
before update on public.orders
for each row execute function public.set_updated_at();

-- RPC: generate_order_number (e.g., OP-YYYYMMDD-xxxxx)
create or replace function public.generate_order_number()
returns text language plpgsql as $$
declare
  seq bigint;
  today text := to_char(now(), 'YYYYMMDD');
begin
  -- Use a simple day-based sequence using orders count for the day
  select count(*) + 1 into seq from public.orders where to_char(created_at, 'YYYYMMDD') = today;
  return 'OP-' || today || '-' || lpad(seq::text, 5, '0');
end $$;

-- RPC: generate_qr_code (placeholder string token)
create or replace function public.generate_qr_code()
returns text language plpgsql as $$
begin
  return 'QR-' || encode(gen_random_bytes(8), 'hex');
end $$;

-- Basic RLS
alter table public.orders enable row level security;

-- Policies: allow authenticated users to read/insert/update
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'orders' and policyname = 'orders_select_authenticated'
  ) then
    create policy orders_select_authenticated on public.orders
      for select to authenticated using (true);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'orders' and policyname = 'orders_insert_authenticated'
  ) then
    create policy orders_insert_authenticated on public.orders
      for insert to authenticated with check (true);
  end if;

  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'orders' and policyname = 'orders_update_authenticated'
  ) then
    create policy orders_update_authenticated on public.orders
      for update to authenticated using (true) with check (true);
  end if;
end $$;

-- Helpful indexes
create index if not exists idx_orders_status_created_at on public.orders(status, created_at desc);
create index if not exists idx_orders_fish_product_id on public.orders(fish_product_id);


