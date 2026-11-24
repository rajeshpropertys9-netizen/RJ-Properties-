-- Enforce the same 1 MB upload cap for public property listing photos.
-- Existing files remain in storage and existing property records are untouched.
update storage.buckets
set file_size_limit = 1000000,
    allowed_mime_types = array['image/webp','image/jpeg']
where id = 'property-photos';
