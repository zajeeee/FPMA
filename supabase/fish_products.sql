-- ===============================
-- 🐟 Fish Products & Inspections Schema
-- ===============================

-- Enable UUID generation (recommended)
create extension if not exists "pgcrypto";

-- 1) Create table: fish_products
create table if not exists fish_products (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid, -- links to inspections table (future)
  species text not null check (species in (
    'bangus', 'tilapia', 'galunggong', 'tamban', 'tulingan', 
    'lapuLapu', 'mayaMaya', 'tanigue', 'dalagangBukid', 'sapsap', 'other'
  )),
  size text, -- e.g., "Small", "Medium", "Large", "Extra Large"
  weight decimal(10,2), -- in kilograms
  vessel_info text, -- general vessel information
  vessel_name text, -- specific vessel name
  vessel_registration text, -- vessel registration number
  image_url text, -- Supabase Storage URL for fish photo
  qr_code text unique, -- QR code identifier
  inspector_id uuid not null, -- who inspected this
  inspector_name text not null, -- inspector's name for display
  status text check (status in ('pending', 'approved', 'rejected', 'cleared')) default 'pending',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2) Create table: inspections (for future workflow)
create table if not exists inspections (
  id uuid primary key default gen_random_uuid(),
  fish_product_id uuid references fish_products(id) on delete cascade,
  inspector_id uuid not null,
  inspector_name text not null,
  inspection_date timestamptz default now(),
  notes text,
  status text check (status in ('pending', 'approved', 'rejected')) default 'pending',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3) Create table: orders (Phase 3 - Order of Payment)
create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  fish_product_id uuid references fish_products(id) on delete cascade,
  order_number text unique not null,
  amount decimal(10,2) not null,
  collector_id uuid not null,
  collector_name text not null,
  status text check (status in ('pending', 'paid', 'cancelled')) default 'pending',
  qr_code text unique, -- QR code for this order
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 4) Create table: receipts (Phase 3 - Official Receipt)
create table if not exists receipts (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete cascade,
  receipt_number text unique not null,
  amount_paid decimal(10,2) not null,
  teller_id uuid not null,
  teller_name text not null,
  payment_date timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 5) Create table: clearing_certificates (Phase 3 - Final Certificate)
create table if not exists clearing_certificates (
  id uuid primary key default gen_random_uuid(),
  fish_product_id uuid references fish_products(id) on delete cascade,
  receipt_id uuid references receipts(id) on delete cascade,
  certificate_number text unique not null,
  qr_code text unique not null, -- QR code for gate validation
  status text check (status in ('active', 'used', 'expired')) default 'active',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 6) Create table: gate_validations (Phase 3 - Gate Collector logs)
create table if not exists gate_validations (
  id uuid primary key default gen_random_uuid(),
  certificate_id uuid references clearing_certificates(id) on delete cascade,
  qr_code text not null,
  gate_collector_id uuid not null,
  gate_collector_name text not null,
  validation_result text check (validation_result in ('valid', 'invalid', 'expired')) not null,
  validation_notes text,
  validated_at timestamptz default now()
);

-- 7) Triggers for auto-updating updated_at
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Apply triggers to all tables
create trigger update_fish_products_updated_at
  before update on fish_products
  for each row execute function update_updated_at_column();

create trigger update_inspections_updated_at
  before update on inspections
  for each row execute function update_updated_at_column();

create trigger update_orders_updated_at
  before update on orders
  for each row execute function update_updated_at_column();

create trigger update_receipts_updated_at
  before update on receipts
  for each row execute function update_updated_at_column();

create trigger update_clearing_certificates_updated_at
  before update on clearing_certificates
  for each row execute function update_updated_at_column();

-- 8) Indexes for better performance
create index if not exists idx_fish_products_inspector on fish_products(inspector_id);
create index if not exists idx_fish_products_status on fish_products(status);
create index if not exists idx_fish_products_qr_code on fish_products(qr_code);
create index if not exists idx_orders_fish_product on orders(fish_product_id);
create index if not exists idx_orders_collector on orders(collector_id);
create index if not exists idx_receipts_order on receipts(order_id);
create index if not exists idx_clearing_certificates_qr on clearing_certificates(qr_code);
create index if not exists idx_gate_validations_qr on gate_validations(qr_code);

-- 9) Sample data for testing (optional)
-- insert into fish_products (species, inspector_id, inspector_name, vessel_name) 
-- values ('bangus', '00000000-0000-0000-0000-000000000000', 'Test Inspector', 'Test Vessel');
