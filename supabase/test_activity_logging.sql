-- Test Activity Logging - Run this after applying the fix
-- This will test that the activity logging system works properly

-- Test 1: Insert a test activity log using a real user
DO $$
DECLARE
    test_user_id UUID;
    log_id UUID;
BEGIN
    -- Get the first user from user_profiles
    SELECT user_id INTO test_user_id 
    FROM user_profiles 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        SELECT log_activity(
            test_user_id,
            'admin',
            'test_action',
            'Testing activity logging system',
            'test_ref_123',
            'test_type',
            '{"test": true}'::JSONB
        ) INTO log_id;
        
        RAISE NOTICE 'Test activity log created with ID: %', log_id;
    ELSE
        RAISE NOTICE 'No users found in system, cannot test activity logging';
    END IF;
END $$;

-- Test 2: Query activity logs to verify they exist
SELECT 
    id,
    user_id,
    user_role,
    action,
    description,
    reference_id,
    reference_type,
    created_at
FROM activity_logs 
ORDER BY created_at DESC 
LIMIT 5;

-- Test 3: Verify CSV export query works
SELECT 
    id,
    user_id,
    user_role,
    action,
    description,
    reference_id,
    reference_type,
    created_at
FROM activity_logs 
ORDER BY created_at DESC;

-- Test 4: Check table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'activity_logs' 
ORDER BY ordinal_position;
