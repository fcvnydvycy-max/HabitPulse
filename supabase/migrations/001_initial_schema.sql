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

-- Profiles: users can manage their own profile. Other users can only see
-- a minimal profile when a friendship exists.
create policy "profiles_select_self_or_friend" on public.profiles
for select to authenticated
using (
  id = (select auth.uid()) or exists (
    select 1 from public.friendships f
    where (f.user_low = (select auth.uid()) and f.user_high = id)
       or (f.user_high = (select auth.uid()) and f.user_low = id)
  )
);
create policy "profiles_insert_self" on public.profiles
for insert to authenticated
with check (id = (select auth.uid()));
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

-- Friend requests are visible only to their sender and recipient.
create policy "friend_requests_participant_select" on public.friend_requests
for select to authenticated
using (sender_id = (select auth.uid()) or recipient_id = (select auth.uid()));
create policy "friend_requests_sender_insert" on public.friend_requests
for insert to authenticated
with check (sender_id = (select auth.uid()) and status = 'pending');
create policy "friend_requests_recipient_update" on public.friend_requests
for update to authenticated
using (recipient_id = (select auth.uid()) and status = 'pending')
with check (recipient_id = (select auth.uid()) and status in ('accepted', 'rejected'));

-- Friendships are readable only by either participant. Creation is handled
-- by the trusted acceptance workflow, not by arbitrary client inserts.
create policy "friendships_participant_select" on public.friendships
for select to authenticated
using (user_low = (select auth.uid()) or user_high = (select auth.uid()));

-- Challenges are visible only to their members; creation belongs to creator.
create policy "challenges_member_select" on public.challenges
for select to authenticated
using (
  created_by = (select auth.uid()) or exists (
    select 1 from public.challenge_members cm
    where cm.challenge_id = id and cm.user_id = (select auth.uid())
  )
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
using (
  user_id = (select auth.uid()) or exists (
    select 1 from public.challenges c
    where c.id = challenge_id and c.created_by = (select auth.uid())
  )
);
create policy "challenge_members_self_join" on public.challenge_members
for insert to authenticated
with check (
  user_id = (select auth.uid()) and exists (
    select 1 from public.challenges c where c.id = challenge_id
  )
);
create policy "challenge_entries_member_select" on public.challenge_entries
for select to authenticated
using (exists (
  select 1 from public.challenge_members cm
  where cm.challenge_id = challenge_id and cm.user_id = (select auth.uid())
));
create policy "challenge_entries_self_insert" on public.challenge_entries
for insert to authenticated
with check (user_id = (select auth.uid()) and exists (
  select 1 from public.challenge_members cm
  where cm.challenge_id = challenge_id and cm.user_id = (select auth.uid())
));
create policy "challenge_entries_owner_update_delete" on public.challenge_entries
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
create policy "challenge_entries_owner_delete" on public.challenge_entries
for delete to authenticated
using (user_id = (select auth.uid()));

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
