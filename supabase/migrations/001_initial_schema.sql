-- HabitPulse: initial private schema
-- Run only after reviewing this file. This script is designed for Supabase Free.
-- It does not modify the existing GitHub Pages app or migrate local browser data.

begin;

create extension if not exists pgcrypto;

-- Minimal profile data. Sensitive personal records stay in separate owner-only tables.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text not null default 'HabitPulse user',
  friend_code text not null unique default upper(encode(gen_random_bytes(5), 'hex')),
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_length check (username is null or char_length(username) between 3 and 24),
  constraint profiles_display_name_length check (char_length(display_name) between 1 and 40)
);

create table if not exists public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  icon text,
  color text,
  frequency jsonb not null default '{}'::jsonb,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint habits_title_length check (char_length(title) between 1 and 100)
);

create table if not exists public.habit_entries (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references public.habits(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_date date not null,
  completed boolean not null default false,
  note text,
  created_at timestamptz not null default now(),
  unique (habit_id, entry_date)
);

create table if not exists public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  workout_date timestamptz not null default now(),
  title text not null,
  duration_minutes integer,
  notes text,
  exercises jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  constraint workouts_duration_nonnegative check (duration_minutes is null or duration_minutes >= 0)
);

create table if not exists public.meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  consumed_at timestamptz not null default now(),
  meal_type text,
  description text not null,
  calories numeric(8,2),
  protein_g numeric(8,2),
  carbohydrates_g numeric(8,2),
  fat_g numeric(8,2),
  created_at timestamptz not null default now(),
  constraint meals_nonnegative_macros check (
    (calories is null or calories >= 0) and
    (protein_g is null or protein_g >= 0) and
    (carbohydrates_g is null or carbohydrates_g >= 0) and
    (fat_g is null or fat_g >= 0)
  )
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  due_at timestamptz,
  completed boolean not null default false,
  priority text not null default 'normal',
  category text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tasks_priority_valid check (priority in ('low', 'normal', 'high'))
);

-- Body measurements are private and are never included in friend-facing profiles.
create table if not exists public.body_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  measured_at timestamptz not null default now(),
  weight_kg numeric(6,2),
  body_fat_percent numeric(5,2),
  notes text,
  created_at timestamptz not null default now(),
  constraint body_metrics_nonnegative check (
    (weight_kg is null or weight_kg > 0) and
    (body_fat_percent is null or body_fat_percent between 0 and 100)
  )
);

-- Only metadata is stored in Postgres. Image bytes live in a private Storage bucket.
create table if not exists public.progress_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  taken_at timestamptz not null default now(),
  caption text,
  created_at timestamptz not null default now()
);

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint friend_requests_not_self check (sender_id <> recipient_id),
  constraint friend_requests_status_valid check (status in ('pending', 'accepted', 'rejected', 'cancelled')),
  unique (sender_id, recipient_id)
);

-- Store each friendship once, with the UUIDs in a deterministic order.
create table if not exists public.friendships (
  user_low uuid not null references auth.users(id) on delete cascade,
  user_high uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_low, user_high),
  constraint friendships_distinct_users check (user_low < user_high)
);

create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  starts_on date not null,
  ends_on date not null,
  metric text not null default 'habit_completions',
  target_value numeric(10,2),
  created_at timestamptz not null default now(),
  constraint challenges_dates_valid check (ends_on >= starts_on)
);

create table if not exists public.challenge_members (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (challenge_id, user_id)
);

create table if not exists public.challenge_entries (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_date date not null default current_date,
  value numeric(10,2) not null default 1,
  note text,
  created_at timestamptz not null default now(),
  foreign key (challenge_id, user_id)
    references public.challenge_members(challenge_id, user_id) on delete cascade
);

-- Indexes for the common per-user and date-range queries.
create index if not exists habits_user_id_idx on public.habits(user_id);
create index if not exists habit_entries_user_date_idx on public.habit_entries(user_id, entry_date desc);
create index if not exists workouts_user_date_idx on public.workouts(user_id, workout_date desc);
create index if not exists meals_user_date_idx on public.meals(user_id, consumed_at desc);
create index if not exists tasks_user_due_idx on public.tasks(user_id, due_at);
create index if not exists body_metrics_user_date_idx on public.body_metrics(user_id, measured_at desc);
create index if not exists progress_photos_user_date_idx on public.progress_photos(user_id, taken_at desc);
create index if not exists friend_requests_recipient_status_idx on public.friend_requests(recipient_id, status);
create index if not exists challenge_members_user_idx on public.challenge_members(user_id);

-- Enable RLS on every user-data table.
alter table public.profiles enable row level security;
alter table public.habits enable row level security;
alter table public.habit_entries enable row level security;
alter table public.workouts enable row level security;
alter table public.meals enable row level security;
alter table public.tasks enable row level security;
alter table public.body_metrics enable row level security;
alter table public.progress_photos enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.challenges enable row level security;
alter table public.challenge_members enable row level security;
alter table public.challenge_entries enable row level security;


-- Create a minimal profile automatically when Supabase Auth creates an account.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_display_name text;
  v_username text;
begin
  v_display_name := coalesce(
    nullif(left(trim(new.raw_user_meta_data ->> 'display_name'), 40), ''),
    'HabitPulse user'
  );
  v_username := nullif(lower(regexp_replace(coalesce(new.raw_user_meta_data ->> 'username', ''), '[^a-zA-Z0-9_]', '', 'g')), '');
  if v_username is not null then
    v_username := left(v_username, 24);
    if char_length(v_username) < 3 then v_username := null; end if;
  end if;

  begin
    insert into public.profiles (id, username, display_name)
    values (new.id, v_username, v_display_name)
    on conflict (id) do nothing;
  exception when unique_violation then
    -- A username collision must never prevent account registration.
    insert into public.profiles (id, username, display_name)
    values (new.id, null, v_display_name)
    on conflict (id) do nothing;
  end;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_habitpulse on auth.users;
create trigger on_auth_user_created_habitpulse
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- Look up an exact friend code and return only the small public profile fields.
-- This does not expose email, habits, workouts, nutrition, measurements or photos.
create or replace function public.find_profile_by_friend_code(p_friend_code text)
returns table (user_id uuid, username text, display_name text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id, p.username, p.display_name
  from public.profiles p
  where auth.uid() is not null
    and p.friend_code = upper(trim(p_friend_code))
    and p.id <> auth.uid()
  limit 1;
$$;

revoke all on function public.handle_new_auth_user() from public, anon, authenticated;
revoke all on function public.find_profile_by_friend_code(text) from public, anon;
grant execute on function public.find_profile_by_friend_code(text) to authenticated;



-- List only basic profile fields for accepted friends.
create or replace function public.list_my_friends()
returns table (user_id uuid, username text, display_name text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id, p.username, p.display_name
  from public.friendships f
  join public.profiles p
    on p.id = case
      when f.user_low = auth.uid() then f.user_high
      else f.user_low
    end
  where auth.uid() is not null
    and (f.user_low = auth.uid() or f.user_high = auth.uid())
  order by p.display_name;
$$;

revoke all on function public.list_my_friends() from public, anon;
grant execute on function public.list_my_friends() to authenticated;

-- Send a friend request using a friend code, without exposing arbitrary user IDs.
-- Reversed pending requests are accepted as mutual intent.
create or replace function public.request_friend_by_code(p_friend_code text)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_target uuid;
  v_existing_status text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select p.id into v_target
  from public.profiles p
  where p.friend_code = upper(trim(p_friend_code))
    and p.id <> auth.uid()
  limit 1;

  if v_target is null then
    raise exception 'Friend code not found';
  end if;

  if public.is_friend_of_current_user(v_target) then
    return 'already_friends';
  end if;

  select fr.status into v_existing_status
  from public.friend_requests fr
  where fr.sender_id = v_target
    and fr.recipient_id = auth.uid()
    and fr.status = 'pending'
  limit 1;

  if v_existing_status = 'pending' then
    perform public.respond_to_friend_request(
      (select fr.id from public.friend_requests fr
       where fr.sender_id = v_target and fr.recipient_id = auth.uid()
         and fr.status = 'pending' limit 1),
      'accepted'
    );
    return 'accepted_existing_request';
  end if;

  insert into public.friend_requests(sender_id, recipient_id, status)
  values (auth.uid(), v_target, 'pending')
  on conflict (sender_id, recipient_id) do update
    set status = 'pending', updated_at = now()
    where public.friend_requests.status in ('rejected', 'cancelled');

  return 'request_sent';
end;
$$;

revoke all on function public.request_friend_by_code(text) from public, anon;
grant execute on function public.request_friend_by_code(text) to authenticated;

-- Add the challenge creator as the first participant automatically.
create or replace function public.add_challenge_creator_as_member()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.challenge_members (challenge_id, user_id)
  values (new.id, new.created_by)
  on conflict do nothing;
  return new;
end;
$$;

revoke all on function public.add_challenge_creator_as_member() from public, anon, authenticated;
drop trigger if exists on_habitpulse_challenge_created on public.challenges;
create trigger on_habitpulse_challenge_created
after insert on public.challenges
for each row execute function public.add_challenge_creator_as_member();

-- SECURITY DEFINER helpers avoid recursive RLS checks while always binding
-- the checked user to auth.uid(), preventing arbitrary relationship probing.
create or replace function public.is_current_user_challenge_member(p_challenge_id uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select auth.uid() is not null and exists (
  select 1 from public.challenge_members
  where challenge_id = p_challenge_id and user_id = auth.uid()
); $$;

create or replace function public.is_current_user_challenge_creator(p_challenge_id uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select auth.uid() is not null and exists (
  select 1 from public.challenges
  where id = p_challenge_id and created_by = auth.uid()
); $$;

create or replace function public.is_friend_of_current_user(p_other_user_id uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp
as $$ select auth.uid() is not null and exists (
  select 1 from public.friendships
  where user_low = least(auth.uid(), p_other_user_id)
    and user_high = greatest(auth.uid(), p_other_user_id)
); $$;

revoke all on function public.is_current_user_challenge_member(uuid) from public, anon;
revoke all on function public.is_current_user_challenge_creator(uuid) from public, anon;
revoke all on function public.is_friend_of_current_user(uuid) from public, anon;
grant execute on function public.is_current_user_challenge_member(uuid) to authenticated;
grant execute on function public.is_current_user_challenge_creator(uuid) to authenticated;
grant execute on function public.is_friend_of_current_user(uuid) to authenticated;

-- Return only basic participant identity inside a challenge the caller belongs to.
create or replace function public.list_challenge_members(p_challenge_id uuid)
returns table (user_id uuid, username text, display_name text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select cm.user_id, p.username, p.display_name
  from public.challenge_members cm
  join public.profiles p on p.id = cm.user_id
  where cm.challenge_id = p_challenge_id
    and public.is_current_user_challenge_member(p_challenge_id)
  order by p.display_name;
$$;

revoke all on function public.list_challenge_members(uuid) from public, anon;
grant execute on function public.list_challenge_members(uuid) to authenticated;


-- Accept/reject requests through a trusted function so clients cannot rewrite sender/recipient IDs.
create or replace function public.respond_to_friend_request(p_request_id uuid, p_response text)
returns void language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_sender uuid;
  v_recipient uuid;
begin
  if p_response not in ('accepted', 'rejected') then
    raise exception 'Invalid response';
  end if;

  select sender_id, recipient_id into v_sender, v_recipient
  from public.friend_requests
  where id = p_request_id and status = 'pending'
  for update;

  if not found or v_recipient <> auth.uid() then
    raise exception 'Friend request not found or not permitted';
  end if;

  update public.friend_requests
  set status = p_response, updated_at = now()
  where id = p_request_id;

  if p_response = 'accepted' then
    insert into public.friendships(user_low, user_high)
    values (least(v_sender, v_recipient), greatest(v_sender, v_recipient))
    on conflict do nothing;
  end if;
end;
$$;
revoke all on function public.respond_to_friend_request(uuid, text) from public, anon;
grant execute on function public.respond_to_friend_request(uuid, text) to authenticated;

-- Profiles: users can manage their own profile. Other users can only see
-- a minimal profile when a friendship exists.
-- Profile rows are owner-only. Friend-facing data is exposed only through
-- narrow RPCs below, because RLS alone cannot hide selected columns.
create policy "profiles_select_self" on public.profiles
for select to authenticated
using (id = (select auth.uid()));
-- Profiles are created only by the Auth trigger, never by browser INSERT.
drop policy if exists "profiles_insert_self" on public.profiles;
revoke insert on public.profiles from authenticated;
create policy "profiles_update_self" on public.profiles
for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- Owner-only policies for private personal records.
create policy "habits_owner_all" on public.habits
for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "habit_entries_owner_all" on public.habit_entries
for all to authenticated
using (user_id = (select auth.uid()) and exists (
  select 1 from public.habits h where h.id = habit_id and h.user_id = (select auth.uid())
))
with check (user_id = (select auth.uid()) and exists (
  select 1 from public.habits h where h.id = habit_id and h.user_id = (select auth.uid())
));

create policy "workouts_owner_all" on public.workouts
for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "meals_owner_all" on public.meals
for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "tasks_owner_all" on public.tasks
for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "body_metrics_owner_all" on public.body_metrics
for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "progress_photos_owner_all" on public.progress_photos
for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- Friend codes are generated by the database and cannot be edited by clients.
create or replace function public.prevent_profile_identity_changes()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.id <> old.id or new.friend_code <> old.friend_code then
    raise exception 'Profile identity fields cannot be changed';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_profile_identity_changes() from public, anon, authenticated;
drop trigger if exists protect_habitpulse_profile_identity on public.profiles;
create trigger protect_habitpulse_profile_identity
before update on public.profiles
for each row execute function public.prevent_profile_identity_changes();

-- Friend requests are visible only to their sender and recipient.
create policy "friend_requests_participant_select" on public.friend_requests
for select to authenticated
using (sender_id = (select auth.uid()) or recipient_id = (select auth.uid()));
-- Friend requests can only be created through request_friend_by_code().
drop policy if exists "friend_requests_sender_insert" on public.friend_requests;
revoke insert on public.friend_requests from authenticated;
-- Responses are handled by respond_to_friend_request(); direct client updates are intentionally disabled.

-- Friendships are readable only by either participant. Creation is handled
-- by the trusted acceptance workflow, not by arbitrary client inserts.
create policy "friendships_participant_select" on public.friendships
for select to authenticated
using (user_low = (select auth.uid()) or user_high = (select auth.uid()));

-- Challenges are visible only to their members; creation belongs to creator.
create policy "challenges_member_select" on public.challenges
for select to authenticated
using (
  created_by = (select auth.uid()) or public.is_current_user_challenge_member(id)
);
create policy "challenges_creator_insert" on public.challenges
for insert to authenticated
with check (created_by = (select auth.uid()));
create policy "challenges_creator_update" on public.challenges
for update to authenticated
using (created_by = (select auth.uid()))
with check (created_by = (select auth.uid()));
create policy "challenge_members_member_select" on public.challenge_members
for select to authenticated
using (public.is_current_user_challenge_member(challenge_id));
create policy "challenge_members_self_join" on public.challenge_members
for insert to authenticated
with check (
  user_id = (select auth.uid()) and (
    public.is_current_user_challenge_creator(challenge_id) or exists (
      select 1 from public.challenges c
      where c.id = challenge_id
        and public.is_friend_of_current_user(c.created_by)
    )
  )
);
create policy "challenge_entries_member_select" on public.challenge_entries
for select to authenticated
using (public.is_current_user_challenge_member(challenge_id));
create policy "challenge_entries_self_insert" on public.challenge_entries
for insert to authenticated
with check (user_id = (select auth.uid()) and public.is_current_user_challenge_member(challenge_id));
create policy "challenge_entries_owner_update_delete" on public.challenge_entries
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
create policy "challenge_entries_owner_delete" on public.challenge_entries
for delete to authenticated
using (user_id = (select auth.uid()));

-- Explicit API privileges. RLS remains the row-level boundary for authenticated users.
revoke all on public.profiles, public.habits, public.habit_entries,
  public.workouts, public.meals, public.tasks, public.body_metrics,
  public.progress_photos, public.friend_requests, public.friendships,
  public.challenges, public.challenge_members, public.challenge_entries
from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (username, display_name, avatar_path, updated_at) on public.profiles to authenticated;
grant select, insert, update, delete on public.habits to authenticated;
grant select, insert, update, delete on public.habit_entries to authenticated;
grant select, insert, update, delete on public.workouts to authenticated;
grant select, insert, update, delete on public.meals to authenticated;
grant select, insert, update, delete on public.tasks to authenticated;
grant select, insert, update, delete on public.body_metrics to authenticated;
grant select, insert, update, delete on public.progress_photos to authenticated;
grant select on public.friend_requests to authenticated;
grant select on public.friendships to authenticated;
grant select, insert, update on public.challenges to authenticated;
grant select, insert on public.challenge_members to authenticated;
grant select, insert, update, delete on public.challenge_entries to authenticated;

-- Private bucket for progress photos. No public read access.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'progress-photos',
  'progress-photos',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "progress_photos_storage_select_own" on storage.objects
for select to authenticated
using (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "progress_photos_storage_insert_own" on storage.objects
for insert to authenticated
with check (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "progress_photos_storage_update_own" on storage.objects
for update to authenticated
using (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "progress_photos_storage_delete_own" on storage.objects
for delete to authenticated
using (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

commit;
