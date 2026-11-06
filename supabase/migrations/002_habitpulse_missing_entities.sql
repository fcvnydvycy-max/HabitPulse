-- HabitPulse migration 002: entities missing from the initial Supabase schema
-- Target: HabitPulse-Test (Supabase Free)
-- IMPORTANT: Review this file before running it. This file has NOT been executed.
-- All new records are private to their authenticated owner.

begin;

-- 1) Private settings: never put body measurements or nutrition targets in public.profiles.
create table if not exists public.user_settings (
    user_id uuid primary key references auth.users(id) on delete cascade,
    age_years smallint,
    height_cm numeric(5,2),
    goal text,
    target_kcal integer,
    target_protein_g numeric(7,2),
    target_carbs_g numeric(7,2),
    target_fat_g numeric(7,2),
    target_water_ml integer,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint user_settings_age_check check (age_years is null or age_years between 1 and 120),
    constraint user_settings_height_check check (height_cm is null or height_cm between 50 and 260),
    constraint user_settings_goal_check check (goal is null or length(trim(goal)) between 1 and 80),
    constraint user_settings_target_kcal_check check (target_kcal is null or target_kcal between 0 and 20000),
    constraint user_settings_protein_check check (target_protein_g is null or target_protein_g between 0 and 1000),
    constraint user_settings_carbs_check check (target_carbs_g is null or target_carbs_g between 0 and 2000),
    constraint user_settings_fat_check check (target_fat_g is null or target_fat_g between 0 and 1000),
    constraint user_settings_water_check check (target_water_ml is null or target_water_ml between 0 and 20000)
);

-- 2) Daily water totals. Store millilitres as the canonical quantity (one legacy glass = 250 ml).
create table if not exists public.water_entries (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    entry_date date not null,
    amount_ml integer not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint water_entries_amount_check check (amount_ml between 0 and 20000),
    constraint water_entries_user_date_unique unique (user_id, entry_date)
);

-- 3) Weekly gym routine templates. These are plans, not completed workout records.
-- day_of_week follows ISO convention: Monday=1 ... Sunday=7.
create table if not exists public.gym_routines (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    day_of_week smallint not null,
    title text not null,
    exercises jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint gym_routines_day_check check (day_of_week between 1 and 7),
    constraint gym_routines_title_check check (length(trim(title)) between 1 and 160),
    constraint gym_routines_exercises_array_check check (jsonb_typeof(exercises) = 'array'),
    constraint gym_routines_user_day_unique unique (user_id, day_of_week)
);

-- 4) Saved/favourite meal templates. These are not meals already consumed.
create table if not exists public.favorite_meals (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    meal_type text,
    name text not null,
    calories numeric(9,2),
    protein_g numeric(8,2),
    carbohydrates_g numeric(8,2),
    fat_g numeric(8,2),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint favorite_meals_name_check check (length(trim(name)) between 1 and 240),
    constraint favorite_meals_calories_check check (calories is null or calories between 0 and 100000),
    constraint favorite_meals_protein_check check (protein_g is null or protein_g between 0 and 10000),
    constraint favorite_meals_carbs_check check (carbohydrates_g is null or carbohydrates_g between 0 and 10000),
    constraint favorite_meals_fat_check check (fat_g is null or fat_g between 0 and 10000)
);

-- 5) Academic calendar events. Kept separate from generic tasks.
create table if not exists public.academic_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    title text not null,
    event_date date not null,
    event_type text not null default 'exam',
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint academic_events_title_check check (length(trim(title)) between 1 and 240),
    constraint academic_events_type_check check (length(trim(event_type)) between 1 and 40)
);

create index if not exists academic_events_user_date_idx
    on public.academic_events (user_id, event_date);

-- 6) Study sessions. Weekly totals can be derived from dated sessions.
create table if not exists public.study_sessions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    started_at timestamptz not null,
    duration_minutes integer not null,
    session_type text not null default 'focus',
    completed_at timestamptz,
    created_at timestamptz not null default now(),
    constraint study_sessions_duration_check check (duration_minutes between 1 and 1440),
    constraint study_sessions_type_check check (session_type in ('focus', 'break', 'manual'))
);

create index if not exists study_sessions_user_started_idx
    on public.study_sessions (user_id, started_at desc);

-- 7) Preserve the weight associated with each progress photo, if supplied by the UI.
alter table public.progress_photos
    add column if not exists weight_kg numeric(6,2);

alter table public.progress_photos
    add constraint progress_photos_weight_check
    check (weight_kg is null or weight_kg between 20 and 500);

-- Owner-only Row Level Security for every new table.
alter table public.user_settings enable row level security;
alter table public.water_entries enable row level security;
alter table public.gym_routines enable row level security;
alter table public.favorite_meals enable row level security;
alter table public.academic_events enable row level security;
alter table public.study_sessions enable row level security;

drop policy if exists user_settings_owner_all on public.user_settings;
create policy user_settings_owner_all
    on public.user_settings for all to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

drop policy if exists water_entries_owner_all on public.water_entries;
create policy water_entries_owner_all
    on public.water_entries for all to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

drop policy if exists gym_routines_owner_all on public.gym_routines;
create policy gym_routines_owner_all
    on public.gym_routines for all to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

drop policy if exists favorite_meals_owner_all on public.favorite_meals;
create policy favorite_meals_owner_all
    on public.favorite_meals for all to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

drop policy if exists academic_events_owner_all on public.academic_events;
create policy academic_events_owner_all
    on public.academic_events for all to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

drop policy if exists study_sessions_owner_all on public.study_sessions;
create policy study_sessions_owner_all
    on public.study_sessions for all to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

-- Explicit grants for signed-in users; RLS remains the row-level boundary.
grant select, insert, update, delete on
    public.user_settings,
    public.water_entries,
    public.gym_routines,
    public.favorite_meals,
    public.academic_events,
    public.study_sessions
to authenticated;

revoke all on
    public.user_settings,
    public.water_entries,
    public.gym_routines,
    public.favorite_meals,
    public.academic_events,
    public.study_sessions
from anon;

comment on table public.user_settings is
    'Private per-user HabitPulse settings and nutrition targets; owner-only RLS.';
comment on table public.water_entries is
    'Daily water intake total in millilitres; one row per user and date.';
comment on table public.gym_routines is
    'Weekly gym routine templates; separate from completed workouts.';
comment on table public.favorite_meals is
    'Saved meal templates; separate from consumed meals.';
comment on table public.academic_events is
    'Private academic calendar events such as exams; separate from tasks.';
comment on table public.study_sessions is
    'Dated study/focus sessions used to derive weekly study totals.';

commit;
