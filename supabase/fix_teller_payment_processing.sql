-- Comprehensive fix for Teller payment processing and QR code generation
-- This script ensures all required tables and functions exist

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Ensure receipts table exists with proper structure
CREATE TABLE IF NOT EXISTS public.receipts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid,
    receipt_number text NOT NULL UNIQUE,
    teller_id uuid NOT NULL,
    teller_name text NOT NULL,
    amount_paid numeric(12,2) NOT NULL,
    payment_date timestamptz DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- 2. Ensure clearing_certificates table exists with proper structure
DROP TABLE IF EXISTS public.clearing_certificates CASCADE;
CREATE TABLE public.clearing_certificates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    official_receipt_id uuid NOT NULL,
    certificate_number text NOT NULL UNIQUE,
    qr_code text,
    status text NOT NULL DEFAULT 'generated' CHECK (status IN ('generated','validated','expired')),
    validated_at timestamptz,
    validated_by uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- 3. Add foreign key constraints
DO $$
BEGIN
    -- Receipts to orders
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'orders'
    ) THEN
        ALTER TABLE public.receipts 
        DROP CONSTRAINT IF EXISTS receipts_order_id_fkey,
        ADD CONSTRAINT receipts_order_id_fkey 
        FOREIGN KEY (order_id) 
        REFERENCES public.orders(id) 
        ON DELETE CASCADE;
    END IF;
    
    -- Clearing certificates to receipts
    ALTER TABLE public.clearing_certificates 
    DROP CONSTRAINT IF EXISTS clearing_certificates_official_receipt_id_fkey,
    ADD CONSTRAINT clearing_certificates_official_receipt_id_fkey 
    FOREIGN KEY (official_receipt_id) 
    REFERENCES public.receipts(id) 
    ON DELETE CASCADE;
END $$;

-- 4. Create required RPC functions
-- Generate receipt number function
CREATE OR REPLACE FUNCTION public.generate_receipt_number()
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
    seq bigint;
    today text := to_char(now(), 'YYYYMMDD');
BEGIN
    SELECT count(*) + 1 INTO seq FROM public.receipts WHERE to_char(created_at, 'YYYYMMDD') = today;
    RETURN 'OR-' || today || '-' || lpad(seq::text, 5, '0');
END $$;

-- Generate certificate number function
CREATE OR REPLACE FUNCTION public.generate_certificate_number()
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
    seq bigint;
    today text := to_char(now(), 'YYYYMMDD');
BEGIN
    SELECT count(*) + 1 INTO seq FROM public.clearing_certificates WHERE to_char(created_at, 'YYYYMMDD') = today;
    RETURN 'CC-' || today || '-' || lpad(seq::text, 5, '0');
END $$;

-- 5. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_receipts_order_id ON public.receipts(order_id);
CREATE INDEX IF NOT EXISTS idx_receipts_teller_id ON public.receipts(teller_id);
CREATE INDEX IF NOT EXISTS idx_receipts_created_at ON public.receipts(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_clearing_certificates_official_receipt_id ON public.clearing_certificates(official_receipt_id);
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_qr_code ON public.clearing_certificates(qr_code);
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_status ON public.clearing_certificates(status);

-- 6. Enable RLS
ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clearing_certificates ENABLE ROW LEVEL SECURITY;

-- 7. Create RLS policies
DO $$
BEGIN
    -- Receipts policies
    DROP POLICY IF EXISTS receipts_select_authenticated ON public.receipts;
    DROP POLICY IF EXISTS receipts_insert_authenticated ON public.receipts;
    DROP POLICY IF EXISTS receipts_update_authenticated ON public.receipts;
    
    CREATE POLICY receipts_select_authenticated ON public.receipts
        FOR SELECT TO authenticated USING (true);
    
    CREATE POLICY receipts_insert_authenticated ON public.receipts
        FOR INSERT TO authenticated WITH CHECK (true);
    
    CREATE POLICY receipts_update_authenticated ON public.receipts
        FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
    
    -- Clearing certificates policies
    DROP POLICY IF EXISTS clearing_certificates_select_authenticated ON public.clearing_certificates;
    DROP POLICY IF EXISTS clearing_certificates_insert_authenticated ON public.clearing_certificates;
    DROP POLICY IF EXISTS clearing_certificates_update_authenticated ON public.clearing_certificates;
    
    CREATE POLICY clearing_certificates_select_authenticated ON public.clearing_certificates
        FOR SELECT TO authenticated USING (true);
    
    CREATE POLICY clearing_certificates_insert_authenticated ON public.clearing_certificates
        FOR INSERT TO authenticated WITH CHECK (true);
    
    CREATE POLICY clearing_certificates_update_authenticated ON public.clearing_certificates
        FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
END $$;

-- 8. Create updated_at triggers
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_receipts_set_updated_at ON public.receipts;
CREATE TRIGGER trg_receipts_set_updated_at
    BEFORE UPDATE ON public.receipts
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_clearing_certificates_set_updated_at ON public.clearing_certificates;
CREATE TRIGGER trg_clearing_certificates_set_updated_at
    BEFORE UPDATE ON public.clearing_certificates
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
