-- Comprehensive fix for Gate Collector Dashboard data loading
-- This script ensures all required tables exist with proper permissions

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Ensure clearing_certificates table exists with proper structure
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

-- 2. Ensure activity_logs table exists with proper structure
DROP TABLE IF EXISTS public.activity_logs CASCADE;
CREATE TABLE public.activity_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    certificate_id text NOT NULL,
    gate_collector_id uuid NOT NULL,
    gate_collector_name text NOT NULL,
    validation_result text NOT NULL CHECK (validation_result IN ('success','fail')),
    message text,
    timestamp timestamptz NOT NULL DEFAULT now()
);

-- 3. Add foreign key constraints
DO $$
BEGIN
    -- Clearing certificates to receipts
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

-- 4. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_status_created_at ON public.clearing_certificates(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_qr_code ON public.clearing_certificates(qr_code);
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_official_receipt_id ON public.clearing_certificates(official_receipt_id);

CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON public.activity_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_certificate_id ON public.activity_logs(certificate_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_gate_collector_id ON public.activity_logs(gate_collector_id);

-- 5. Enable RLS
ALTER TABLE public.clearing_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS policies
DO $$
BEGIN
    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS clearing_certificates_select_authenticated ON public.clearing_certificates;
    DROP POLICY IF EXISTS clearing_certificates_insert_authenticated ON public.clearing_certificates;
    DROP POLICY IF EXISTS clearing_certificates_update_authenticated ON public.clearing_certificates;
    
    DROP POLICY IF EXISTS activity_logs_select_authenticated ON public.activity_logs;
    DROP POLICY IF EXISTS activity_logs_insert_authenticated ON public.activity_logs;
    
    -- Create new policies
    CREATE POLICY clearing_certificates_select_authenticated ON public.clearing_certificates
        FOR SELECT TO authenticated USING (true);
    
    CREATE POLICY clearing_certificates_insert_authenticated ON public.clearing_certificates
        FOR INSERT TO authenticated WITH CHECK (true);
    
    CREATE POLICY clearing_certificates_update_authenticated ON public.clearing_certificates
        FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
    
    CREATE POLICY activity_logs_select_authenticated ON public.activity_logs
        FOR SELECT TO authenticated USING (true);
    
    CREATE POLICY activity_logs_insert_authenticated ON public.activity_logs
        FOR INSERT TO authenticated WITH CHECK (true);
END $$;

-- 7. Create updated_at trigger for clearing_certificates
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

-- 8. Sample data will be created automatically when payments are processed
-- The dashboard will show empty states until real data is available
