-- RJ Properties CRM: enforce the 1 MB owner-photo upload limit.
-- Existing stored photos and metadata are preserved.
update storage.buckets
set file_size_limit = 1000000,
    allowed_mime_types = array['image/webp']
where id = 'rj-owner-property-media';
