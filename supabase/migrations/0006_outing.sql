-- "Let's go out": outing invite card in a friend chat (place + private room code).
alter table public.dms drop constraint if exists dms_kind_chk;
alter table public.dms add constraint dms_kind_chk check (kind in ('text','photo','voice','outing'));

create or replace function public.send_outing(p_uid uuid, p_name text, p_lat double precision, p_lon double precision, p_room text) returns boolean
language plpgsql security definer set search_path to 'public' as $f$
declare n text := left(trim(coalesce(p_name,'')), 60);
begin
  if auth.uid() is null or n = '' then return false; end if;
  if p_lat is null or p_lon is null or p_lat not between -90 and 90 or p_lon not between -180 and 180 then return false; end if;
  if p_room is null or p_room !~ '^[a-z0-9]{4,12}$' then return false; end if;
  if n ~* '(https?://|www\.|t\.me|wa\.me|\.com|\.net|\.org)' or n ~ '[0-9]{6,}' then return false; end if;
  if not exists (select 1 from public.profiles where id = auth.uid() and age_ok) then return false; end if;
  if not exists (select 1 from public.friendships f where f.status = 'accepted' and ((f.requester = auth.uid() and f.target = p_uid) or (f.target = auth.uid() and f.requester = p_uid))) then return false; end if;
  if exists (select 1 from public.blocks k where (k.blocker = p_uid and k.blocked = auth.uid()) or (k.blocker = auth.uid() and k.blocked = p_uid)) then return false; end if;
  if (select count(*) from public.dms where sender = auth.uid() and kind = 'outing' and created_at > now() - interval '24 hours') >= 20 then raise exception 'rate limit'; end if;
  insert into public.dms(sender, recipient, body, kind)
  values (auth.uid(), p_uid, jsonb_build_object('n', n, 'lat', round(p_lat::numeric, 4), 'lon', round(p_lon::numeric, 4), 'room', p_room)::text, 'outing');
  return true;
end $f$;
revoke execute on function public.send_outing(uuid, text, double precision, double precision, text) from public, anon;
grant execute on function public.send_outing(uuid, text, double precision, double precision, text) to authenticated;
select 'ok' as done;
