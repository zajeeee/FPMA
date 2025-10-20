-- Fix QR Scanning Issues - Database Updates
-- This script addresses the QR code detection and validation issues

-- 1. Ensure clearing_certificates table has proper structure and indexes
DO $$
BEGIN
    -- Check if clearing_certificates table exists, if not create it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'clearing_certificates'
    ) THEN
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
    END IF;
END $$;

-- 2. Ensure activity_logs table has the correct structure for gate collector
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

-- 3. Create optimized indexes for QR code scanning
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_qr_code_hash ON public.clearing_certificates USING hash(qr_code);
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_status_created_at ON public.clearing_certificates(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clearing_certificates_validated_at ON public.clearing_certificates(validated_at) WHERE validated_at IS NOT NULL;

-- 4. Create indexes for activity logs
CREATE INDEX IF NOT EXISTS idx_activity_logs_timestamp ON public.activity_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_certificate_id ON public.activity_logs(certificate_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_gate_collector_id ON public.activity_logs(gate_collector_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_validation_result ON public.activity_logs(validation_result);

-- 5. Enable RLS and create policies
ALTER TABLE public.clearing_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS clearing_certificates_select_authenticated ON public.clearing_certificates;
DROP POLICY IF EXISTS clearing_certificates_insert_authenticated ON public.clearing_certificates;
DROP POLICY IF EXISTS clearing_certificates_update_authenticated ON public.clearing_certificates;
DROP POLICY IF EXISTS activity_logs_select_authenticated ON public.activity_logs;
DROP POLICY IF EXISTS activity_logs_insert_authenticated ON public.activity_logs;

-- Create RLS policies
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

-- 6. Create updated_at trigger for clearing_certificates
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

-- 7. Create function to generate certificate numbers
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

-- 8. Create function to validate QR codes with better error handling
CREATE OR REPLACE FUNCTION public.validate_qr_code(
    p_qr_code text,
    p_gate_collector_id uuid,
    p_gate_collector_name text
)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
    cert_record record;
    result jsonb;
    now_time timestamptz := now();
BEGIN
    -- Find certificate by QR code with better error handling
    BEGIN
        SELECT * INTO cert_record
        FROM public.clearing_certificates
        WHERE qr_code = p_qr_code;
        
        IF NOT FOUND THEN
            -- Log failed attempt
            INSERT INTO public.activity_logs (
                certificate_id,
                gate_collector_id,
                gate_collector_name,
                validation_result,
                message,
                timestamp
            ) VALUES (
                'unknown',
                p_gate_collector_id,
                p_gate_collector_name,
                'fail',
                'QR code not found in database',
                now_time
            );
            
            RETURN jsonb_build_object(
                'success', false,
                'message', 'QR code not found or invalid',
                'error', 'Certificate not found'
            );
        END IF;
        
        -- Check certificate validity
        IF cert_record.status = 'generated' THEN
            -- Check if certificate is not expired (24 hours)
            IF (now_time - cert_record.created_at) <= interval '24 hours' THEN
                -- Update certificate status
                UPDATE public.clearing_certificates
                SET status = 'validated',
                    validated_at = now_time,
                    validated_by = p_gate_collector_id
                WHERE id = cert_record.id;
                
                -- Log success
                INSERT INTO public.activity_logs (
                    certificate_id,
                    gate_collector_id,
                    gate_collector_name,
                    validation_result,
                    message,
                    timestamp
                ) VALUES (
                    cert_record.id,
                    p_gate_collector_id,
                    p_gate_collector_name,
                    'success',
                    'Certificate validated successfully',
                    now_time
                );
                
                RETURN jsonb_build_object(
                    'success', true,
                    'message', 'Certificate is valid and ready for gate clearance',
                    'certificate', row_to_json(cert_record)
                );
            ELSE
                -- Certificate expired
                UPDATE public.clearing_certificates
                SET status = 'expired'
                WHERE id = cert_record.id;
                
                -- Log failure
                INSERT INTO public.activity_logs (
                    certificate_id,
                    gate_collector_id,
                    gate_collector_name,
                    validation_result,
                    message,
                    timestamp
                ) VALUES (
                    cert_record.id,
                    p_gate_collector_id,
                    p_gate_collector_name,
                    'fail',
                    'Certificate has expired (older than 24 hours)',
                    now_time
                );
                
                RETURN jsonb_build_object(
                    'success', false,
                    'message', 'Certificate has expired (older than 24 hours)',
                    'certificate', row_to_json(cert_record)
                );
            END IF;
        ELSIF cert_record.status = 'validated' THEN
            -- Check grace period (1 hour)
            IF (now_time - cert_record.validated_at) <= interval '1 hour' THEN
                -- Log success
                INSERT INTO public.activity_logs (
                    certificate_id,
                    gate_collector_id,
                    gate_collector_name,
                    validation_result,
                    message,
                    timestamp
                ) VALUES (
                    cert_record.id,
                    p_gate_collector_id,
                    p_gate_collector_name,
                    'success',
                    'Certificate was already validated and is still within grace period',
                    now_time
                );
                
                RETURN jsonb_build_object(
                    'success', true,
                    'message', 'Certificate was already validated and is still within grace period',
                    'certificate', row_to_json(cert_record)
                );
            ELSE
                -- Grace period expired
                INSERT INTO public.activity_logs (
                    certificate_id,
                    gate_collector_id,
                    gate_collector_name,
                    validation_result,
                    message,
                    timestamp
                ) VALUES (
                    cert_record.id,
                    p_gate_collector_id,
                    p_gate_collector_name,
                    'fail',
                    'Certificate validation has expired (grace period exceeded)',
                    now_time
                );
                
                RETURN jsonb_build_object(
                    'success', false,
                    'message', 'Certificate validation has expired (grace period exceeded)',
                    'certificate', row_to_json(cert_record)
                );
            END IF;
        ELSIF cert_record.status = 'expired' THEN
            -- Log failure
            INSERT INTO public.activity_logs (
                certificate_id,
                gate_collector_id,
                gate_collector_name,
                validation_result,
                message,
                timestamp
            ) VALUES (
                cert_record.id,
                p_gate_collector_id,
                p_gate_collector_name,
                'fail',
                'Certificate has expired and cannot be used',
                now_time
            );
            
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Certificate has expired and cannot be used',
                'certificate', row_to_json(cert_record)
            );
        ELSE
            -- Invalid status
            INSERT INTO public.activity_logs (
                certificate_id,
                gate_collector_id,
                gate_collector_name,
                validation_result,
                message,
                timestamp
            ) VALUES (
                cert_record.id,
                p_gate_collector_id,
                p_gate_collector_name,
                'fail',
                'Certificate status is invalid',
                now_time
            );
            
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Certificate status is invalid',
                'certificate', row_to_json(cert_record)
            );
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        -- Log error
        INSERT INTO public.activity_logs (
            certificate_id,
            gate_collector_id,
            gate_collector_name,
            validation_result,
            message,
            timestamp
        ) VALUES (
            'unknown',
            p_gate_collector_id,
            p_gate_collector_name,
            'fail',
            'Database error during validation: ' || SQLERRM,
            now_time
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Database error during validation',
            'error', SQLERRM
        );
    END;
END $$;

-- 9. Grant necessary permissions
GRANT ALL ON public.clearing_certificates TO authenticated;
GRANT ALL ON public.activity_logs TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_certificate_number() TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_qr_code(text, uuid, text) TO authenticated;

-- 10. Create a view for better QR code validation reporting
CREATE OR REPLACE VIEW public.qr_validation_stats AS
SELECT 
    DATE(timestamp) as validation_date,
    validation_result,
    COUNT(*) as validation_count,
    COUNT(DISTINCT certificate_id) as unique_certificates,
    COUNT(DISTINCT gate_collector_id) as unique_gate_collectors
FROM public.activity_logs
WHERE timestamp >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(timestamp), validation_result
ORDER BY validation_date DESC, validation_result;

GRANT SELECT ON public.qr_validation_stats TO authenticated;

-- 11. Create function to clean up old activity logs (optional maintenance)
CREATE OR REPLACE FUNCTION public.cleanup_old_activity_logs()
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
    deleted_count integer;
BEGIN
    DELETE FROM public.activity_logs 
    WHERE timestamp < CURRENT_DATE - INTERVAL '90 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END $$;

GRANT EXECUTE ON FUNCTION public.cleanup_old_activity_logs() TO authenticated;

-- 12. Verify the setup
SELECT 
    'Database setup completed successfully' as status,
    COUNT(*) as clearing_certificates_count,
    (SELECT COUNT(*) FROM public.activity_logs) as activity_logs_count
FROM public.clearing_certificates;
