-- Fix orders table to ensure quantity column exists
-- This script ensures the orders table has all required columns

-- Check if quantity column exists, if not add it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'orders' 
        AND column_name = 'quantity'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN quantity integer;
    END IF;
END $$;

-- Check if due_date column exists, if not add it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'orders' 
        AND column_name = 'due_date'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN due_date timestamptz;
    END IF;
END $$;

-- Ensure the orders table has all required columns with correct types
-- This will recreate the table structure if needed
CREATE TABLE IF NOT EXISTS public.orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fish_product_id uuid,
    order_number text NOT NULL UNIQUE,
    collector_id uuid NOT NULL,
    collector_name text NOT NULL,
    amount numeric(12,2) NOT NULL CHECK (amount >= 0),
    quantity integer,
    due_date timestamptz,
    qr_code text,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','issued','paid')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Add foreign key constraint if fish_products table exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'fish_products'
    ) THEN
        -- Drop existing constraint if it exists
        ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_fish_product_id_fkey;
        -- Add new constraint
        ALTER TABLE public.orders 
        ADD CONSTRAINT orders_fish_product_id_fkey 
        FOREIGN KEY (fish_product_id) 
        REFERENCES public.fish_products(id) 
        ON DELETE SET NULL;
    END IF;
END $$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_orders_status_created_at ON public.orders(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_fish_product_id ON public.orders(fish_product_id);
CREATE INDEX IF NOT EXISTS idx_orders_qr_code ON public.orders(qr_code);

-- Enable RLS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
DO $$
BEGIN
    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS orders_select_authenticated ON public.orders;
    DROP POLICY IF EXISTS orders_insert_authenticated ON public.orders;
    DROP POLICY IF EXISTS orders_update_authenticated ON public.orders;
    
    -- Create new policies
    CREATE POLICY orders_select_authenticated ON public.orders
        FOR SELECT TO authenticated USING (true);
    
    CREATE POLICY orders_insert_authenticated ON public.orders
        FOR INSERT TO authenticated WITH CHECK (true);
    
    CREATE POLICY orders_update_authenticated ON public.orders
        FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
END $$;

-- Create or replace the updated_at trigger
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_orders_set_updated_at ON public.orders;
CREATE TRIGGER trg_orders_set_updated_at
    BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
