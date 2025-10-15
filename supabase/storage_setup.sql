-- Storage setup for QR codes and other files

-- Create storage bucket for QR codes
INSERT INTO storage.buckets (id, name, public)
VALUES ('public', 'public', true)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS policies for public bucket
CREATE POLICY "Public bucket is publicly accessible" ON storage.objects
FOR SELECT USING (bucket_id = 'public');

CREATE POLICY "Authenticated users can upload to public bucket" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'public' 
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Authenticated users can update public bucket files" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'public' 
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Authenticated users can delete public bucket files" ON storage.objects
FOR DELETE USING (
  bucket_id = 'public' 
  AND auth.role() = 'authenticated'
);

-- Create folder structure
-- Note: Folders are created automatically when files are uploaded to them