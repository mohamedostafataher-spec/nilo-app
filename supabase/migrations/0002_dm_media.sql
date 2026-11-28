-- Chat photos and voice notes (private bucket, friends only, server-checked).
alter table public.dms add column if not exists kind text not null default 'text';
alter table public.dms add column if not exists media_path text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'dms_kind_chk') then
    alter table public.dms add constraint dms_kind_chk check (kind in ('text','photo','voice'));
  end if;
end $$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('dm', 'dm', false, 3145728, array['image/jpeg','image/png','image/webp','audio/mp4','audio/aac','audio/mpeg','audio/x-m4a','audio/m4a'])
on conflict (id) do update set public = false, file_size_limit = 3145728, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists dm_media_insert on storage.objects;
drop policy if exists dm_media_select on storage.objects;
drop policy if exists dm_media_delete on storage.objects;
create policy dm_media_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'dm' and (storage.foldername(name))[1] = auth.uid()::text);
create policy dm_media_select on storage.objects for select to authenticated
  using (bucket_id = 'dm' and ((storage.foldername(name))[1] = auth.uid()::text
    or exists (select 1 from public.dms d where d.media_path = storage.objects.name and d.recipient = auth.uid() and d.reports < 2)));
create policy dm_media_delete on storage.objects for delete to authenticated
  using (bucket_id = 'dm' and (storage.foldername(name))[1] = auth.uid()::text);

create or replace function public.send_dm_media(p_uid uuid, p_kind text, p_path text) returns boolean
language plpgsql security definer set search_path to 'public' as $f$
begin
  if auth.uid() is null or p_kind not in ('photo','voice') then return false; end if;
  if p_path is null or p_path not like auth.uid()::text || '/%' then return false; end if;
  if not exists (select 1 from storage.objects where bucket_id = 'dm' and name = p_path) then return false; end if;
  if not exists (select 1 from public.profiles where id = auth.uid() and age_ok) then return false; end if;
  if not exists (select 1 from public.friendships f where f.status = 'accepted' and ((f.requester = auth.uid() and f.target = p_uid) or (f.target = auth.uid() and f.requester = p_uid))) then return false; end if;
  if exists (select 1 from public.blocks k where (k.blocker = p_uid and k.blocked = auth.uid()) or (k.blocker = auth.uid() and k.blocked = p_uid)) then return false; end if;
  if (select count(*) from public.dms where sender = auth.uid() and kind <> 'text' and created_at > now() - interval '24 hours') >= 60 then raise exception 'rate limit'; end if;
  insert into public.dms(sender, recipient, body, kind, media_path) values (auth.uid(), p_uid, '', p_kind, p_path);
  return true;
end $f$;
revoke execute on function public.send_dm_media(uuid, text, text) from public, anon;
grant execute on function public.send_dm_media(uuid, text, text) to authenticated;
select 'ok' as done;
