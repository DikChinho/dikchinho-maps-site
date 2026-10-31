-- DikChinho Navigation — initial PostGIS schema
-- Run ONLY in a new, dedicated DikChinho Supabase project.
-- Do NOT run this in the CER Tracker project.
-- Public reports require authenticated users; add server-side rate limiting and moderation before production.

create schema if not exists extensions;
create extension if not exists postgis with schema extensions;

create table if not exists public.road_segments (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'osm',
  source_type text,
  source_id text,
  name text,
  name_bn text,
  highway text,
  access text,
  motor_vehicle text,
  motorcycle text,
  bicycle text,
  foot text,
  width_m numeric(6,2),
  surface text,
  smoothness text,
  one_way boolean,
  verified_status text not null default 'unverified'
    check (verified_status in ('unverified','community_checked','field_verified','rejected')),
  verified_at timestamptz,
  attributes jsonb not null default '{}'::jsonb,
  geom extensions.geometry(LineString,4326) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source, source_type, source_id)
);

create index if not exists road_segments_geom_gix
  on public.road_segments using gist (geom);
create index if not exists road_segments_highway_idx
  on public.road_segments (highway);
create index if not exists road_segments_verified_idx
  on public.road_segments (verified_status);

create table if not exists public.place_names (
  id uuid primary key default gen_random_uuid(),
  canonical_name text not null,
  name_en text,
  name_bn text,
  aliases text[] not null default '{}',
  category text,
  entrance_note text,
  source text not null default 'community',
  source_id text,
  verified_status text not null default 'unverified'
    check (verified_status in ('unverified','community_checked','field_verified','rejected')),
  verified_at timestamptz,
  location extensions.geometry(Point,4326) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists place_names_location_gix
  on public.place_names using gist (location);
create index if not exists place_names_name_en_idx
  on public.place_names using gin (to_tsvector('simple', coalesce(name_en,'')));
create index if not exists place_names_name_bn_idx
  on public.place_names using gin (to_tsvector('simple', coalesce(name_bn,'')));

create table if not exists public.road_reports (
  id uuid primary key default gen_random_uuid(),
  kind text not null
    check (kind in ('congestion','closure','construction','waterlogging','crash','pothole','hazard')),
  details text check (char_length(details) <= 500),
  severity smallint not null default 2 check (severity between 1 and 3),
  status text not null default 'active'
    check (status in ('active','confirmed','cleared','expired','rejected')),
  location extensions.geometry(Point,4326) not null,
  created_by uuid not null references auth.users(id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (expires_at > created_at),
  check (expires_at <= created_at + interval '7 days')
);

create index if not exists road_reports_location_gix
  on public.road_reports using gist (location);
create index if not exists road_reports_active_expiry_idx
  on public.road_reports (status, expires_at);

create table if not exists public.road_report_votes (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.road_reports(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  vote smallint not null check (vote in (-1,1)),
  created_at timestamptz not null default now(),
  unique (report_id, user_id)
);

alter table public.road_segments enable row level security;
alter table public.place_names enable row level security;
alter table public.road_reports enable row level security;
alter table public.road_report_votes enable row level security;

-- Public users can read published road/place reference data. Writes are reserved
-- for trusted ingestion/moderation services, not browser clients.
drop policy if exists "public_read_road_segments" on public.road_segments;
create policy "public_read_road_segments"
  on public.road_segments for select to anon, authenticated using (verified_status in ('community_checked','field_verified'));

drop policy if exists "public_read_place_names" on public.place_names;
create policy "public_read_place_names"
  on public.place_names for select to anon, authenticated using (verified_status in ('community_checked','field_verified'));

-- Only unexpired, non-rejected road reports are visible to the public.
drop policy if exists "public_read_active_road_reports" on public.road_reports;
create policy "public_read_active_road_reports"
  on public.road_reports for select to anon, authenticated
  using (status in ('active','confirmed') and expires_at > now());

-- Authenticated users may submit a report as themselves. No public anonymous
-- insert policy is created; this avoids an unrestricted spam endpoint.
drop policy if exists "authenticated_create_road_reports" on public.road_reports;
create policy "authenticated_create_road_reports"
  on public.road_reports for insert to authenticated
  with check (
    created_by = auth.uid()
    and expires_at > now()
    and expires_at <= now() + interval '7 days'
  );

drop policy if exists "authenticated_vote_road_reports" on public.road_report_votes;
create policy "authenticated_vote_road_reports"
  on public.road_report_votes for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "users_remove_own_road_report_votes" on public.road_report_votes;
create policy "users_remove_own_road_report_votes"
  on public.road_report_votes for delete to authenticated
  using (user_id = auth.uid());

-- No update/delete policy is intentionally provided for road reports and road
-- reference data. Add moderated server-side workflows before enabling edits.

-- Explicit column grants keep report authors' auth UUIDs private. Policies alone
-- are not grants; both privileges and RLS must allow a request.
grant select on public.road_segments, public.place_names to anon, authenticated;

grant select (id, kind, details, severity, status, location, created_at, expires_at)
  on public.road_reports to anon, authenticated;
grant insert (kind, details, severity, location, expires_at)
  on public.road_reports to authenticated;

-- Votes can be submitted/removed by their owner, but individual voter IDs are
-- not readable through the Data API.
grant insert (report_id, user_id, vote) on public.road_report_votes to authenticated;
grant delete on public.road_report_votes to authenticated;
