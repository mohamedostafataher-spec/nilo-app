-- One shared status layer for friends DMs, papyrus conversations and groups.
-- Privacy defaults: friends = online ON, read receipts ON. Strangers (papyrus partners, group members) = online OFF, read receipts OFF.
alter table public.profiles add column if not exists show_online_str boolean not null default false;
alter table public.profiles add column if not exists read_receipts_str boolean not null default false;
alter table public.replies add column if not exists delivered_at timestamptz;
alter table public.replies add column if not exists read_at timestamptz;
alter table public.bottles add column if not exists read_at timestamptz;
create table if not exists public.chat_reads (grp uuid not null, uid uuid not null, at timestamptz not null default now(), primary key (grp, uid));
alter table public.chat_reads enable row level security;
revoke all on public.chat_reads from anon, authenticated;

create or replace function public.relation(p_peer uuid) returns text language sql stable security definer set search_path to 'public' as $f$
  select case
    when auth.uid() is null or p_peer is null or p_peer = auth.uid() then null
    when exists (select 1 from public.blocks k where (k.blocker = p_peer and k.blocked = auth.uid()) or (k.blocker = auth.uid() and k.blocked = p_peer)) then null
    when exists (select 1 from public.friendships f where f.status = 'accepted' and ((f.requester = auth.uid() and f.target = p_peer) or (f.target = auth.uid() and f.requester = p_peer))) then 'friend'
    when exists (select 1 from public.bottles b where (b.author = auth.uid() and b.catcher = p_peer) or (b.author = p_peer and b.catcher = auth.uid())) then 'stranger'
    else null end;
$f$;
create or replace function public.chat_ok(p_peer uuid) returns boolean language sql stable security definer set search_path to 'public' as $f$
  select public.relation(p_peer) is not null;
$f$;
create or replace function public.rcp_flag(p_uid uuid, p_rel text) returns boolean language sql stable security definer set search_path to 'public' as $f$
  select coalesce((select case when p_rel = 'friend' then read_receipts else read_receipts_str end from public.profiles where id = p_uid), false);
$f$;

create or replace function public.touch_seen() returns void language plpgsql security definer set search_path to 'public' as $f$
begin
  if auth.uid() is null then return; end if;
  update public.profiles set last_seen = now() where id = auth.uid();
  update public.dms set delivered_at = now() where recipient = auth.uid() and delivered_at is null;
  update public.replies r set delivered_at = now() from public.bottles b where r.bottle_id = b.id and r.delivered_at is null and r.author <> auth.uid() and (b.author = auth.uid() or b.catcher = auth.uid());
end $f$;

create or replace function public.dm_status(p_peer uuid) returns json language plpgsql stable security definer set search_path to 'public' as $f$
declare rel text := public.relation(p_peer); ls timestamptz; so boolean; mine boolean; ty boolean; rr boolean; mrr boolean;
begin
  if rel is null then return json_build_object('ok', false); end if;
  select last_seen, case when rel = 'friend' then show_online else show_online_str end into ls, so from public.profiles where id = p_peer;
  select case when rel = 'friend' then show_online else show_online_str end into mine from public.profiles where id = auth.uid();
  rr := public.rcp_flag(p_peer, rel); mrr := public.rcp_flag(auth.uid(), rel);
  select exists (select 1 from public.dm_typing where uid = p_peer and peer = auth.uid() and at > now() - interval '6 seconds') into ty;
  return json_build_object('ok', true, 'rel', rel, 'typing', ty,
    'online', case when so and mine and ls is not null then ls > now() - interval '70 seconds' else null end,
    'seen_s', case when so and mine and ls is not null then extract(epoch from (now() - ls))::int else null end,
    'receipts', rr and mrr);
end $f$;

create or replace function public.dm_open(p_peer uuid) returns void language plpgsql security definer set search_path to 'public' as $f$
declare rel text := public.relation(p_peer);
begin
  if rel is null then return; end if;
  update public.dms set delivered_at = coalesce(delivered_at, now()) where recipient = auth.uid() and sender = p_peer and delivered_at is null;
  if public.rcp_flag(auth.uid(), rel) then
    update public.dms set read_at = now() where recipient = auth.uid() and sender = p_peer and read_at is null;
  end if;
  update public.profiles set last_seen = now() where id = auth.uid();
end $f$;

-- Papyrus conversation opened: replies from the other person become delivered and (if I allow) read; the papyrus itself is read when its catcher opens it.
create or replace function public.papyrus_open(p_bid uuid) returns void language plpgsql security definer set search_path to 'public' as $f$
declare b public.bottles; o uuid; rel text;
begin
  select * into b from public.bottles where id = p_bid and (author = auth.uid() or catcher = auth.uid());
  if b.id is null then return; end if;
  o := case when b.author = auth.uid() then b.catcher else b.author end;
  rel := public.relation(o);
  update public.replies set delivered_at = coalesce(delivered_at, now()) where bottle_id = p_bid and author <> auth.uid() and delivered_at is null;
  if rel is not null and public.rcp_flag(auth.uid(), rel) then
    update public.replies set read_at = now() where bottle_id = p_bid and author <> auth.uid() and read_at is null;
    if b.catcher = auth.uid() and b.read_at is null then update public.bottles set read_at = now() where id = p_bid; end if;
  end if;
  update public.profiles set last_seen = now() where id = auth.uid();
end $f$;

create or replace function public.grp_open(p_grp uuid) returns void language plpgsql security definer set search_path to 'public' as $f$
begin
  if not public.nilo_in_group(p_grp) then return; end if;
  if public.rcp_flag(auth.uid(), 'stranger') then
    insert into public.chat_reads(grp, uid, at) values (p_grp, auth.uid(), now()) on conflict (grp, uid) do update set at = now();
  end if;
  update public.profiles set last_seen = now() where id = auth.uid();
end $f$;
create or replace function public.grp_typing(p_grp uuid) returns void language plpgsql security definer set search_path to 'public' as $f$
begin
  if not public.nilo_in_group(p_grp) then return; end if;
  insert into public.dm_typing(uid, peer, at) values (auth.uid(), p_grp, now()) on conflict (uid, peer) do update set at = now();
end $f$;
-- Group status: who is typing (nicks), how many are online (only members who allow it, and only if I allow it), and read times of members who allow receipts.
create or replace function public.grp_status(p_grp uuid) returns json language plpgsql stable security definer set search_path to 'public' as $f$
declare mine boolean; mrr boolean;
begin
  if not public.nilo_in_group(p_grp) then return json_build_object('ok', false); end if;
  select show_online_str into mine from public.profiles where id = auth.uid();
  mrr := public.rcp_flag(auth.uid(), 'stranger');
  return json_build_object('ok', true, 'receipts', mrr,
    'typing', coalesce((select json_agg(p.nick) from public.dm_typing t join public.profiles p on p.id = t.uid join public.chat_members m on m.uid = t.uid and m.grp = p_grp where t.peer = p_grp and t.uid <> auth.uid() and t.at > now() - interval '6 seconds'
        and not exists (select 1 from public.blocks k where (k.blocker = t.uid and k.blocked = auth.uid()) or (k.blocker = auth.uid() and k.blocked = t.uid))), '[]'::json),
    'online', case when mine then (select count(*) from public.chat_members m join public.profiles p on p.id = m.uid where m.grp = p_grp and m.uid <> auth.uid() and p.show_online_str and p.last_seen > now() - interval '70 seconds') else null end,
    'reads', case when mrr then coalesce((select json_agg(r.at) from public.chat_reads r join public.chat_members m on m.uid = r.uid and m.grp = p_grp where r.grp = p_grp and r.uid <> auth.uid()), '[]'::json) else '[]'::json end);
end $f$;

drop function if exists public.set_chat_privacy(boolean, boolean);
create or replace function public.set_chat_privacy(p_online boolean default null, p_receipts boolean default null, p_online_str boolean default null, p_receipts_str boolean default null) returns void language sql security definer set search_path to 'public' as $f$
  update public.profiles set show_online = coalesce(p_online, show_online), read_receipts = coalesce(p_receipts, read_receipts), show_online_str = coalesce(p_online_str, show_online_str), read_receipts_str = coalesce(p_receipts_str, read_receipts_str) where id = auth.uid();
$f$;
create or replace function public.my_chat_privacy() returns json language sql stable security definer set search_path to 'public' as $f$
  select json_build_object('online', show_online, 'receipts', read_receipts, 'online_str', show_online_str, 'receipts_str', read_receipts_str) from public.profiles where id = auth.uid();
$f$;

revoke execute on function public.relation(uuid), public.rcp_flag(uuid, text), public.chat_ok(uuid), public.papyrus_open(uuid), public.grp_open(uuid), public.grp_typing(uuid), public.grp_status(uuid), public.set_chat_privacy(boolean, boolean, boolean, boolean), public.my_chat_privacy() from public, anon;
grant execute on function public.papyrus_open(uuid), public.grp_open(uuid), public.grp_typing(uuid), public.grp_status(uuid), public.set_chat_privacy(boolean, boolean, boolean, boolean), public.my_chat_privacy() to authenticated;
select 'ok' as done;
