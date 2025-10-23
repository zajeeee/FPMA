-- Apply Activity Logs Fix - Run this in Supabase SQL Editor
-- This will fix the missing created_at column and ensure proper schema

-- Step 1: Add created_at column if it doesn't exist
DO $$
BEGIN
    -- Check if created_at column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'activity_logs' AND column_name = 'created_at'
    ) THEN
        -- Add created_at column
        ALTER TABLE activity_logs 
        ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        
        -- If there's existing data with timestamp column, copy it
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'activity_logs' AND column_name = 'timestamp'
        ) THEN
            UPDATE activity_logs 
            SET created_at = timestamp 
            WHERE timestamp IS NOT NULL;
        END IF;
        
        RAISE NOTICE 'Added created_at column to activity_logs table';
    ELSE
        RAISE NOTICE 'created_at column already exists in activity_logs table';
    END IF;
END $$;

-- Step 2: Ensure all required columns exist
DO $$
BEGIN
    -- Add user_id if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'activity_logs' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE activity_logs 
        ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
        RAISE NOTICE 'Added user_id column';
    END IF;
    
    -- Add user_role if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'activity_logs' AND column_name = 'user_role'
    ) THEN
        ALTER TABLE activity_logs 
        ADD COLUMN user_role TEXT;
        RAISE NOTICE 'Added user_role column';
    END IF;
    
    -- Add action if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'activity_logs' AND column_name = 'action'
    ) THEN
        ALTER TABLE activity_logs 
        ADD COLUMN action TEXT;
        RAISE NOTICE 'Added action column';
    END IF;
    
    -- Add description if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'activity_logs' AND column_name = 'description'
    ) THEN
        ALTER TABLE activity_logs 
        ADD COLUMN description TEXT;
        RAISE NOTICE 'Added description column';
    END IF;
    
    -- Add reference_id if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'activity_logs' AND column_name = 'reference_id'
    ) THEN
        ALTER TABLE activity_logs 
        ADD COLUMN reference_id TEXT;
        RAISE NOTICE 'Added reference_id column';
    END IF;
    
    -- Add reference_type if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'activity_logs' AND column_name = 'reference_type'
    ) THEN
        ALTER TABLE activity_logs 
        ADD COLUMN reference_type TEXT;
        RAISE NOTICE 'Added reference_type column';
    END IF;
    
    -- Add metadata if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'activity_logs' AND column_name = 'metadata'
    ) THEN
        ALTER TABLE activity_logs 
        ADD COLUMN metadata JSONB;
        RAISE NOTICE 'Added metadata column';
    END IF;
END $$;

-- Step 3: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action ON activity_logs(action);
CREATE INDEX IF NOT EXISTS idx_activity_logs_reference ON activity_logs(reference_type, reference_id);

-- Step 4: Ensure RLS is enabled
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

-- Step 5: Create/Update RLS policies
DROP POLICY IF EXISTS "Admins can view all activity logs" ON activity_logs;
DROP POLICY IF EXISTS "Users can view own activity logs" ON activity_logs;
DROP POLICY IF EXISTS "System can insert activity logs" ON activity_logs;

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

-- Step 6: Update the log_activity function
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

-- Step 7: Insert a test activity log to verify everything works
-- Only insert if there are actual users in the system
DO $$
DECLARE
    test_user_id UUID;
BEGIN
    -- Get the first admin user from user_profiles
    SELECT user_id INTO test_user_id 
    FROM user_profiles 
    WHERE role = 'admin' 
    LIMIT 1;
    
    -- If no admin user found, get any user
    IF test_user_id IS NULL THEN
        SELECT user_id INTO test_user_id 
        FROM user_profiles 
        LIMIT 1;
    END IF;
    
    -- If we found a user, insert test log
    IF test_user_id IS NOT NULL THEN
        INSERT INTO activity_logs (
            user_id,
            user_role,
            action,
            description,
            created_at
        ) VALUES (
            test_user_id,
            'admin',
            'system_initialized',
            'Activity logs system initialized and tested',
            NOW()
        );
        RAISE NOTICE 'Test activity log inserted for user: %', test_user_id;
    ELSE
        RAISE NOTICE 'No users found in system, skipping test log insertion';
    END IF;
END $$;

-- Success message
SELECT 'Activity logs schema fix applied successfully!' as status;
