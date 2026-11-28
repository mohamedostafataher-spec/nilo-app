-- Chat status: delivered/read ticks, online/last seen, typing, privacy toggles. All writes go through RPCs.
alter table public.dms add column if not exists delivered_at timestamptz;
alter table public.dms add column if not exists read_at timestamptz;
alter table public.profiles add column if not exists last_seen timestamptz;
alter table public.profiles add column if not exists show_online boolean not null default true;
alter table public.profiles add column if not exists read_receipts boolean not null default true;
create table if not exists public.dm_typing (uid uuid not null, peer uuid not null, at timestamptz not null default now(), primary key (uid, peer));
alter table public.dm_typing enable row level security;
revoke all on public.dm_typing from anon, authenticated;

create or replace function public.chat_ok(p_peer uuid) returns boolean language sql stable security definer set search_path to 'public' as $f$
  select auth.uid() is not null and exists (select 1 from public.friendships f where f.status = 'accepted' and ((f.requester = auth.uid() and f.target = p_peer) or (f.target = auth.uid() and f.requester = p_peer)))
    and not exists (select 1 from public.blocks k where (k.blocker = p_peer and k.blocked = auth.uid()) or (k.blocker = auth.uid() and k.blocked = p_peer));
$f$;

-- Heartbeat while the app is open: updates last seen and marks everything sent to me as delivered.
create or replace function public.touch_seen() returns void language plpgsql security definer set search_path to 'public' as $f$
begin
  if auth.uid() is null then return; end if;
  update public.profiles set last_seen = now() where id = auth.uid();
  update public.dms set delivered_at = now() where recipient = auth.uid() and delivered_at is null;
end $f$;

-- Chat open and visible: marks the peer's messages delivered and, if I allow read receipts, read.
create or replace function public.dm_open(p_peer uuid) returns void language plpgsql security definer set search_path to 'public' as $f$
begin
  if not public.chat_ok(p_peer) then return; end if;
  update public.dms set delivered_at = coalesce(delivered_at, now()) where recipient = auth.uid() and sender = p_peer and delivered_at is null;
  if (select read_receipts from public.profiles where id = auth.uid()) then
    update public.dms set read_at = now() where recipient = auth.uid() and sender = p_peer and read_at is null;
  end if;
  update public.profiles set last_seen = now() where id = auth.uid();
end $f$;

create or replace function public.dm_typing(p_peer uuid) returns void language plpgsql security definer set search_path to 'public' as $f$
begin
  if not public.chat_ok(p_peer) then return; end if;
  insert into public.dm_typing(uid, peer, at) values (auth.uid(), p_peer, now()) on conflict (uid, peer) do update set at = now();
end $f$;

-- Peer status. Online/last seen is shown only when BOTH people allow it (same rule as WhatsApp). Typing is shown while friends.
create or replace function public.dm_status(p_peer uuid) returns json language plpgsql stable security definer set search_path to 'public' as $f$
declare ls timestamptz; so boolean; mine boolean; ty boolean; rr boolean; mrr boolean;
begin
  if not public.chat_ok(p_peer) then return json_build_object('ok', false); end if;
  select last_seen, show_online, read_receipts into ls, so, rr from public.profiles where id = p_peer;
  select show_online, read_receipts into mine, mrr from public.profiles where id = auth.uid();
  select exists (select 1 from public.dm_typing where uid = p_peer and peer = auth.uid() and at > now() - interval '6 seconds') into ty;
  return json_build_object('ok', true, 'typing', ty,
    'online', case when so and mine and ls is not null then ls > now() - interval '70 seconds' else null end,
    'seen_s', case when so and mine and ls is not null then extract(epoch from (now() - ls))::int else null end,
    'receipts', coalesce(rr, true) and coalesce(mrr, true));
end $f$;

create or replace function public.set_chat_privacy(p_online boolean, p_receipts boolean) returns void language sql security definer set search_path to 'public' as $f$
  update public.profiles set show_online = p_online, read_receipts = p_receipts where id = auth.uid();
$f$;
create or replace function public.my_chat_privacy() returns json language sql stable security definer set search_path to 'public' as $f$
  select json_build_object('online', show_online, 'receipts', read_receipts) from public.profiles where id = auth.uid();
$f$;

revoke execute on function public.chat_ok(uuid), public.touch_seen(), public.dm_open(uuid), public.dm_typing(uuid), public.dm_status(uuid), public.set_chat_privacy(boolean, boolean), public.my_chat_privacy() from public, anon;
grant execute on function public.touch_seen(), public.dm_open(uuid), public.dm_typing(uuid), public.dm_status(uuid), public.set_chat_privacy(boolean, boolean), public.my_chat_privacy() to authenticated;
select 'ok' as done;
