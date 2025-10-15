-- Fix existing receipts with "Unknown Teller" to show correct teller names
-- This script updates receipts to use the actual teller name from user_profiles

-- Update receipts where teller_name is "Unknown Teller" to use the actual teller name
UPDATE public.receipts 
SET teller_name = up.full_name,
    updated_at = now()
FROM public.user_profiles up
WHERE receipts.teller_id = up.user_id 
  AND receipts.teller_name = 'Unknown Teller'
  AND up.full_name IS NOT NULL 
  AND up.full_name != '';

-- If there are still receipts with "Unknown Teller" and no matching user profile,
-- update them to use a generic name based on the teller_id
UPDATE public.receipts 
SET teller_name = 'Teller User',
    updated_at = now()
WHERE teller_name = 'Unknown Teller'
  AND teller_id NOT IN (
    SELECT user_id FROM public.user_profiles 
    WHERE full_name IS NOT NULL AND full_name != ''
  );

-- Verify the update
SELECT 
  receipt_number,
  teller_name,
  amount_paid,
  payment_date
FROM public.receipts 
ORDER BY created_at DESC 
LIMIT 10;
