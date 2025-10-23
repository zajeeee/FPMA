-- Fix Activity Logs Schema - Ensure created_at column exists
-- This migration ensures the activity_logs table has the correct schema for general activity logging

-- First, check if the table exists and has the correct structure
DO $$
BEGIN
    -- Check if activity_logs table exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'activity_logs') THEN
        -- Create the table if it doesn't exist
        CREATE TABLE activity_logs (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
            user_role TEXT NOT NULL,
            action TEXT NOT NULL,
            description TEXT,
            reference_id TEXT,
            reference_type TEXT,
            metadata JSONB,
            ip_address INET,
            user_agent TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
    ELSE
        -- Table exists, check if created_at column exists
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'activity_logs' AND column_name = 'created_at'
        ) THEN
            -- Add created_at column if it doesn't exist
            ALTER TABLE activity_logs 
            ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        END IF;
        
        -- Check if timestamp column exists (legacy column)
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'activity_logs' AND column_name = 'timestamp'
        ) THEN
            -- If timestamp exists but created_at doesn't, copy data
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'activity_logs' AND column_name = 'created_at'
            ) THEN
                ALTER TABLE activity_logs 
                ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
                
                -- Copy timestamp data to created_at
                UPDATE activity_logs 
                SET created_at = timestamp 
                WHERE timestamp IS NOT NULL;
            END IF;
        END IF;
    END IF;
END $$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action ON activity_logs(action);
CREATE INDEX IF NOT EXISTS idx_activity_logs_reference ON activity_logs(reference_type, reference_id);

-- Enable RLS
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can view all activity logs" ON activity_logs;
DROP POLICY IF EXISTS "Users can view own activity logs" ON activity_logs;
DROP POLICY IF EXISTS "System can insert activity logs" ON activity_logs;

-- Create RLS policies
CREATE POLICY "Admins can view all activity logs" ON activity_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_profiles.user_id = auth.uid() 
            AND user_profiles.role = 'admin'
        )
    );

CREATE POLICY "Users can view own activity logs" ON activity_logs
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "System can insert activity logs" ON activity_logs
    FOR INSERT WITH CHECK (true);

-- Update the log_activity function to ensure it uses created_at
CREATE OR REPLACE FUNCTION log_activity(
    p_user_id UUID,
    p_user_role TEXT,
    p_action TEXT,
    p_description TEXT DEFAULT NULL,
    p_reference_id TEXT DEFAULT NULL,
    p_reference_type TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    log_id UUID;
BEGIN
    INSERT INTO activity_logs (
        user_id,
        user_role,
        action,
        description,
        reference_id,
        reference_type,
        metadata,
        created_at
    ) VALUES (
        p_user_id,
        p_user_role,
        p_action,
        p_description,
        p_reference_id,
        p_reference_type,
        p_metadata,
        NOW()
    ) RETURNING id INTO log_id;
    
    RETURN log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add some sample activity logs for testing (optional)
-- INSERT INTO activity_logs (user_id, user_role, action, description, created_at) VALUES
-- ('00000000-0000-0000-0000-000000000000', 'admin', 'system_startup', 'System initialized', NOW()),
-- ('00000000-0000-0000-0000-000000000000', 'admin', 'Password Changed', 'Password change feature implemented', NOW());
