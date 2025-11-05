-- Final Activity Logs Setup - Run this in Supabase SQL Editor
-- This ensures the activity_logs table is properly configured for all implemented actions

-- Step 1: Create activity_logs table if it doesn't exist
CREATE TABLE IF NOT EXISTS activity_logs (
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

-- Step 2: Ensure all required columns exist with proper constraints
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
        ADD COLUMN user_role TEXT NOT NULL;
        RAISE NOTICE 'Added user_role column';
    END IF;
    
    -- Add action if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'activity_logs' AND column_name = 'action'
    ) THEN
        ALTER TABLE activity_logs 
        ADD COLUMN action TEXT NOT NULL;
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
    
    -- Add ip_address if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'activity_logs' AND column_name = 'ip_address'
    ) THEN
        ALTER TABLE activity_logs 
        ADD COLUMN ip_address INET;
        RAISE NOTICE 'Added ip_address column';
    END IF;
    
    -- Add user_agent if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'activity_logs' AND column_name = 'user_agent'
    ) THEN
        ALTER TABLE activity_logs 
        ADD COLUMN user_agent TEXT;
        RAISE NOTICE 'Added user_agent column';
    END IF;
    
    -- Add created_at if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'activity_logs' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE activity_logs 
        ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        RAISE NOTICE 'Added created_at column';
    END IF;
END $$;

-- Step 3: Create indexes for optimal performance
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action ON activity_logs(action);
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_role ON activity_logs(user_role);
CREATE INDEX IF NOT EXISTS idx_activity_logs_reference ON activity_logs(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_metadata ON activity_logs USING GIN(metadata);

-- Step 4: Enable RLS
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

-- Step 5: Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Admins can view all activity logs" ON activity_logs;
DROP POLICY IF EXISTS "Users can view own activity logs" ON activity_logs;
DROP POLICY IF EXISTS "System can insert activity logs" ON activity_logs;

-- Step 6: Create RLS policies
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

-- Step 7: Create/Update the log_activity function
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

-- Step 8: Insert test activity logs to verify everything works
DO $$
DECLARE
    test_user_id UUID;
    admin_user_id UUID;
BEGIN
    -- Get the first admin user from user_profiles
    SELECT user_id INTO admin_user_id 
    FROM user_profiles 
    WHERE role = 'admin' 
    LIMIT 1;
    
    -- If no admin user found, get any user
    IF admin_user_id IS NULL THEN
        SELECT user_id INTO test_user_id 
        FROM user_profiles 
        LIMIT 1;
    ELSE
        test_user_id := admin_user_id;
    END IF;
    
    -- If we found a user, insert test logs for all implemented actions
    IF test_user_id IS NOT NULL THEN
        -- System initialization
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
        
        -- Test login activity
        INSERT INTO activity_logs (
            user_id,
            user_role,
            action,
            description,
            metadata,
            created_at
        ) VALUES (
            test_user_id,
            'admin',
            'login',
            'Test login activity',
            ('{"test": true, "timestamp": "' || NOW()::text || '"}')::jsonb,
            NOW()
        );
        
        -- Test password change
        INSERT INTO activity_logs (
            user_id,
            user_role,
            action,
            description,
            created_at
        ) VALUES (
            test_user_id,
            'admin',
            'Password Changed',
            'Test password change activity',
            NOW()
        );
        
        RAISE NOTICE 'Test activity logs inserted for user: %', test_user_id;
    ELSE
        RAISE NOTICE 'No users found in system, skipping test log insertion';
    END IF;
END $$;

-- Step 9: Create a view for activity log statistics
CREATE OR REPLACE VIEW activity_log_stats AS
SELECT 
    action,
    user_role,
    COUNT(*) as count,
    MAX(created_at) as last_occurrence
FROM activity_logs 
GROUP BY action, user_role
ORDER BY count DESC;

-- Step 10: Create a function to clean up old activity logs (optional maintenance)
CREATE OR REPLACE FUNCTION cleanup_old_activity_logs(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM activity_logs 
    WHERE created_at < NOW() - INTERVAL '1 day' * days_to_keep;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Success message
SELECT 'Activity logs system setup completed successfully!' as status,
       'All activity logging features are now ready to use.' as message;
