-- Complete fix for clearing_certificates table
-- This script ensures the clearing_certificates table is properly set up

-- First, ensure the receipts table exists (it should from teller_receipts.sql)
-- If not, create a basic one
CREATE TABLE IF NOT EXISTS public.receipts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid,
    receipt_number text UNIQUE NOT NULL,
    amount_paid decimal(10,2) NOT NULL,
    teller_id uuid NOT NULL,
    teller_name text NOT NULL,
    payment_date timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Drop and recreate clearing_certificates table to ensure proper schema
DROP TABLE IF EXISTS public.clearing_certificates CASCADE;

-- Create clearing_certificates table with proper schema
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

-- Add foreign key constraint to receipts table
ALTER TABLE public.clearing_certificates 
ADD CONSTRAINT clearing_certificates_official_receipt_id_fkey 
FOREIGN KEY (official_receipt_id) 
REFERENCES public.receipts(id) 
ON DELETE CASCADE;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_status_created_at ON public.clearing_certificates(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_qr_code ON public.clearing_certificates(qr_code);
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_official_receipt_id ON public.clearing_certificates(official_receipt_id);
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_certificate_number ON public.clearing_certificates(certificate_number);

-- Enable RLS
ALTER TABLE public.clearing_certificates ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS clearing_certificates_select_authenticated ON public.clearing_certificates;
DROP POLICY IF EXISTS clearing_certificates_insert_authenticated ON public.clearing_certificates;
DROP POLICY IF EXISTS clearing_certificates_update_authenticated ON public.clearing_certificates;

-- Create RLS policies
CREATE POLICY clearing_certificates_select_authenticated ON public.clearing_certificates
    FOR SELECT TO authenticated USING (true);

CREATE POLICY clearing_certificates_insert_authenticated ON public.clearing_certificates
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY clearing_certificates_update_authenticated ON public.clearing_certificates
    FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- Create or replace the updated_at trigger function
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END $$;

-- Create trigger for updated_at
DROP TRIGGER IF EXISTS trg_clearing_certificates_set_updated_at ON public.clearing_certificates;
CREATE TRIGGER trg_clearing_certificates_set_updated_at
    BEFORE UPDATE ON public.clearing_certificates
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Create RPC function to generate certificate numbers
CREATE OR REPLACE FUNCTION public.generate_certificate_number()
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
    seq bigint;
    today text := to_char(now(), 'YYYYMMDD');
BEGIN
    SELECT count(*) + 1 INTO seq 
    FROM public.clearing_certificates 
    WHERE to_char(created_at, 'YYYYMMDD') = today;
    
    RETURN 'CC-' || today || '-' || lpad(seq::text, 5, '0');
END $$;

-- Grant necessary permissions
GRANT ALL ON public.clearing_certificates TO authenticated;
GRANT ALL ON public.receipts TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_certificate_number() TO authenticated;

-- Insert a test record to verify the table works (optional - remove in production)
-- INSERT INTO public.clearing_certificates (
--     official_receipt_id,
--     certificate_number,
--     qr_code,
--     status
-- ) VALUES (
--     gen_random_uuid(), -- This will fail due to FK constraint, but that's expected
--     'CC-TEST-001',
--     'TEST-QR-CODE',
--     'generated'
-- );

-- Verify table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'clearing_certificates'
ORDER BY ordinal_position;
