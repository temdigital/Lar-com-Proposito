begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('brand-public', 'brand-public', true, 5242880, array['image/jpeg','image/png','image/webp','image/svg+xml']),
  ('avatars', 'avatars', true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('course-materials', 'course-materials', false, 52428800, array['application/pdf','image/jpeg','image/png','image/webp','application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
  ('community-media', 'community-media', false, 10485760, array['image/jpeg','image/png','image/webp','application/pdf']),
  ('documents-private', 'documents-private', false, 20971520, array['application/pdf','image/jpeg','image/png','image/webp']),
  ('certificates', 'certificates', false, 10485760, array['application/pdf'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Leitura pública somente para elementos de marca e avatares.
create policy storage_public_assets_read
on storage.objects for select to anon, authenticated
using (bucket_id in ('brand-public','avatars'));

-- Avatares: caminho organization_id/user_id/arquivo.
create policy storage_avatars_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[2] = auth.uid()::text
  and public.is_organization_member(public.try_uuid((storage.foldername(name))[1]))
);

create policy storage_avatars_update
on storage.objects for update to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[2] = auth.uid()::text)
with check (bucket_id = 'avatars' and (storage.foldername(name))[2] = auth.uid()::text);

create policy storage_avatars_delete
on storage.objects for delete to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[2] = auth.uid()::text);

-- Materiais de curso: organization_id/course_id/arquivo.
create policy storage_course_materials_read
on storage.objects for select to authenticated
using (
  bucket_id = 'course-materials'
  and (
    public.has_active_enrollment(public.try_uuid((storage.foldername(name))[2]))
    or public.has_permission(public.try_uuid((storage.foldername(name))[1]), 'courses.read')
  )
);

create policy storage_course_materials_manage
on storage.objects for all to authenticated
using (
  bucket_id = 'course-materials'
  and public.has_permission(public.try_uuid((storage.foldername(name))[1]), 'courses.manage')
)
with check (
  bucket_id = 'course-materials'
  and public.has_permission(public.try_uuid((storage.foldername(name))[1]), 'courses.manage')
);

-- Comunidade: organization_id/space_id/arquivo.
create policy storage_community_media_read
on storage.objects for select to authenticated
using (
  bucket_id = 'community-media'
  and public.can_access_community_space(public.try_uuid((storage.foldername(name))[2]))
);

create policy storage_community_media_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'community-media'
  and public.can_access_community_space(public.try_uuid((storage.foldername(name))[2]))
);

create policy storage_community_media_manage
on storage.objects for update to authenticated
using (
  bucket_id = 'community-media'
  and (
    owner_id = auth.uid()::text
    or public.has_permission(public.try_uuid((storage.foldername(name))[1]), 'community.moderate')
  )
)
with check (bucket_id = 'community-media');

create policy storage_community_media_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'community-media'
  and (
    owner_id = auth.uid()::text
    or public.has_permission(public.try_uuid((storage.foldername(name))[1]), 'community.moderate')
  )
);

-- Documentos privados e certificados: organization_id/user_id/arquivo.
create policy storage_private_documents_self
on storage.objects for select to authenticated
using (
  bucket_id in ('documents-private','certificates')
  and (
    (storage.foldername(name))[2] = auth.uid()::text
    or public.has_permission(public.try_uuid((storage.foldername(name))[1]), 'media.manage')
  )
);

create policy storage_private_documents_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'documents-private'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy storage_private_documents_manage
on storage.objects for all to authenticated
using (
  bucket_id in ('documents-private','certificates')
  and public.has_permission(public.try_uuid((storage.foldername(name))[1]), 'media.manage')
)
with check (
  bucket_id in ('documents-private','certificates')
  and public.has_permission(public.try_uuid((storage.foldername(name))[1]), 'media.manage')
);

-- Marca pública: somente equipe autorizada grava.
create policy storage_brand_manage
on storage.objects for all to authenticated
using (
  bucket_id = 'brand-public'
  and public.has_permission(public.try_uuid((storage.foldername(name))[1]), 'media.manage')
)
with check (
  bucket_id = 'brand-public'
  and public.has_permission(public.try_uuid((storage.foldername(name))[1]), 'media.manage')
);

commit;
