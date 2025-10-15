-- Fix clearing_certificates table schema
-- This script ensures the clearing_certificates table has all required columns

-- Drop and recreate the clearing_certificates table to ensure proper schema
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

-- Add foreign key constraint to receipts table if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'receipts'
    ) THEN
        ALTER TABLE public.clearing_certificates 
        ADD CONSTRAINT clearing_certificates_official_receipt_id_fkey 
        FOREIGN KEY (official_receipt_id) 
        REFERENCES public.receipts(id) 
        ON DELETE CASCADE;
    END IF;
END $$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_status_created_at ON public.clearing_certificates(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_qr_code ON public.clearing_certificates(qr_code);
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_official_receipt_id ON public.clearing_certificates(official_receipt_id);

-- Enable RLS
ALTER TABLE public.clearing_certificates ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
DO $$
BEGIN
    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS clearing_certificates_select_authenticated ON public.clearing_certificates;
    DROP POLICY IF EXISTS clearing_certificates_insert_authenticated ON public.clearing_certificates;
    DROP POLICY IF EXISTS clearing_certificates_update_authenticated ON public.clearing_certificates;
    
    -- Create new policies
    CREATE POLICY clearing_certificates_select_authenticated ON public.clearing_certificates
        FOR SELECT TO authenticated USING (true);
    
    CREATE POLICY clearing_certificates_insert_authenticated ON public.clearing_certificates
        FOR INSERT TO authenticated WITH CHECK (true);
    
    CREATE POLICY clearing_certificates_update_authenticated ON public.clearing_certificates
        FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
END $$;

-- Create or replace the updated_at trigger
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_clearing_certificates_set_updated_at ON public.clearing_certificates;
CREATE TRIGGER trg_clearing_certificates_set_updated_at
    BEFORE UPDATE ON public.clearing_certificates
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
