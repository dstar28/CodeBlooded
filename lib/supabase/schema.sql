-- =====================================================================
-- SafeGuard — Supabase schema (Prompt #12: backend foundation)
-- =====================================================================
--
-- IMPORTANT — READ BEFORE RUNNING:
--
-- 1. Run this in the Supabase SQL editor (or via the CLI) against your
--    own project. It contains no real credentials.
-- 2. Row Level Security below is written against `auth.uid()`, i.e. a
--    real Supabase Auth session. SafeGuard's UI still uses mock/local
--    login as of this prompt (see lib/services/supabase/local_identity.dart),
--    so writes made under the demo user id will be correctly REJECTED by
--    these policies until real Supabase Auth is connected in a later
--    prompt. The Flutter app treats that rejection as a normal backend
--    error and shows "Unable to sync" — this is intentional, not a bug.
--    Do not weaken these policies to make the demo user "work"; that
--    would defeat the point of RLS.
-- 3. Never store: passport number, Aadhaar number, passport image,
--    medical records, continuous GPS history, or blockchain private keys
--    in any table here.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id text primary key,
  full_name text not null default '',
  tourist_type text not null default 'domestic',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid()::text = id);

create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid()::text = id);

create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid()::text = id)
  with check (auth.uid()::text = id);

-- ---------------------------------------------------------------------
-- trips
-- ---------------------------------------------------------------------
create table if not exists public.trips (
  id text primary key,
  user_id text not null,
  title text not null,
  destination text not null,
  origin text not null default 'Current Location',
  start_date timestamptz not null,
  end_date timestamptz not null,
  status text not null default 'upcoming',
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists trips_user_id_idx on public.trips (user_id);

alter table public.trips enable row level security;

create policy "trips_select_own"
  on public.trips for select
  using (auth.uid()::text = user_id);

create policy "trips_insert_own"
  on public.trips for insert
  with check (auth.uid()::text = user_id);

create policy "trips_update_own"
  on public.trips for update
  using (auth.uid()::text = user_id)
  with check (auth.uid()::text = user_id);

create policy "trips_delete_own"
  on public.trips for delete
  using (auth.uid()::text = user_id);

-- ---------------------------------------------------------------------
-- emergency_contacts
-- ---------------------------------------------------------------------
create table if not exists public.emergency_contacts (
  id text primary key,
  user_id text not null,
  name text not null,
  phone text not null,
  relationship text not null default '',
  email text not null default '',
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists emergency_contacts_user_id_idx
  on public.emergency_contacts (user_id);

alter table public.emergency_contacts enable row level security;

create policy "emergency_contacts_select_own"
  on public.emergency_contacts for select
  using (auth.uid()::text = user_id);

create policy "emergency_contacts_insert_own"
  on public.emergency_contacts for insert
  with check (auth.uid()::text = user_id);

create policy "emergency_contacts_update_own"
  on public.emergency_contacts for update
  using (auth.uid()::text = user_id)
  with check (auth.uid()::text = user_id);

create policy "emergency_contacts_delete_own"
  on public.emergency_contacts for delete
  using (auth.uid()::text = user_id);

-- ---------------------------------------------------------------------
-- safety_circles / safety_circle_members
-- ---------------------------------------------------------------------
create table if not exists public.safety_circles (
  id text primary key,
  name text not null,
  invite_code text not null unique,
  created_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.safety_circle_members (
  circle_id text not null references public.safety_circles (id) on delete cascade,
  user_id text not null,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  status text not null default 'active',
  primary key (circle_id, user_id)
);

create index if not exists safety_circle_members_user_id_idx
  on public.safety_circle_members (user_id);

alter table public.safety_circles enable row level security;
alter table public.safety_circle_members enable row level security;

-- A user may see a circle only if they're a member of it.
create policy "safety_circles_select_member"
  on public.safety_circles for select
  using (
    exists (
      select 1 from public.safety_circle_members m
      where m.circle_id = safety_circles.id
        and m.user_id = auth.uid()::text
    )
  );

create policy "safety_circles_insert_creator"
  on public.safety_circles for insert
  with check (auth.uid()::text = created_by);

create policy "safety_circles_update_creator"
  on public.safety_circles for update
  using (auth.uid()::text = created_by)
  with check (auth.uid()::text = created_by);

-- Membership rows: a user can see membership rows for circles they
-- belong to (needed to render the member list), and can only insert or
-- remove their own membership row.
create policy "safety_circle_members_select_fellow_members"
  on public.safety_circle_members for select
  using (
    exists (
      select 1 from public.safety_circle_members m2
      where m2.circle_id = safety_circle_members.circle_id
        and m2.user_id = auth.uid()::text
    )
  );

create policy "safety_circle_members_insert_self"
  on public.safety_circle_members for insert
  with check (auth.uid()::text = user_id);

create policy "safety_circle_members_delete_self"
  on public.safety_circle_members for delete
  using (auth.uid()::text = user_id);

-- ---------------------------------------------------------------------
-- incidents
-- ---------------------------------------------------------------------
create table if not exists public.incidents (
  id uuid primary key default gen_random_uuid(),
  incident_id text not null unique,
  user_id text not null,
  trip_id text,
  type text not null,
  description text not null default '',
  latitude double precision,
  longitude double precision,
  incident_time timestamptz not null,
  source text not null default 'userReport',
  status text not null default 'reported',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists incidents_user_id_idx on public.incidents (user_id);
create index if not exists incidents_incident_time_idx on public.incidents (incident_time);

alter table public.incidents enable row level security;

create policy "incidents_select_own"
  on public.incidents for select
  using (auth.uid()::text = user_id);

create policy "incidents_insert_own"
  on public.incidents for insert
  with check (auth.uid()::text = user_id);

create policy "incidents_update_own"
  on public.incidents for update
  using (auth.uid()::text = user_id)
  with check (auth.uid()::text = user_id);

-- ---------------------------------------------------------------------
-- tourist_credentials
-- ---------------------------------------------------------------------
create table if not exists public.tourist_credentials (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  credential_id text not null unique,
  credential_hash text not null,
  issuer_id text not null,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists tourist_credentials_user_id_idx
  on public.tourist_credentials (user_id);

alter table public.tourist_credentials enable row level security;

create policy "tourist_credentials_select_own"
  on public.tourist_credentials for select
  using (auth.uid()::text = user_id);

create policy "tourist_credentials_insert_own"
  on public.tourist_credentials for insert
  with check (auth.uid()::text = user_id);

create policy "tourist_credentials_update_own"
  on public.tourist_credentials for update
  using (auth.uid()::text = user_id)
  with check (auth.uid()::text = user_id);