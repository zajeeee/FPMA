-- ===============================
-- 🚀 MVP User Management Schema (No RLS/Policies)
-- ===============================

-- Enable UUID generation (recommended)
create extension if not exists "pgcrypto";

-- 1) Create table: user_profiles
create table if not exists user_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade, -- links to Supabase Auth
  full_name text not null,
  email text not null unique,
  role text check (role in ('admin','inspector','collector','gateCollector','teller')) default 'inspector',
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2) Trigger for auto-updating updated_at
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger update_user_profiles_updated_at
before update on user_profiles
for each row
execute function update_updated_at_column();