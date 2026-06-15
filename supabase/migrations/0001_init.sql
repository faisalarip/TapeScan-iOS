-- TapeScan — initial schema (M7).
-- Apply with: supabase db push   (or the SQL editor in the dashboard)

create table public.measurements (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  collection text not null default 'measurements',
  payload text not null,                  -- base64 of the client DTO JSON
  updated_at timestamptz not null,
  deleted_at timestamptz
);

create table public.rooms (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  collection text not null default 'rooms',
  payload text not null,
  updated_at timestamptz not null,
  deleted_at timestamptz
);

create index measurements_user_updated on public.measurements (user_id, updated_at);
create index rooms_user_updated on public.rooms (user_id, updated_at);

-- Owner-only row-level security: the client never filters by user; the
-- database enforces it.
alter table public.measurements enable row level security;
alter table public.rooms enable row level security;

create policy "own measurements" on public.measurements
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own rooms" on public.rooms
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- In-app account deletion (App Store Guideline 5.1.1(v)): deleting the auth
-- user cascades to both tables via the foreign keys above.
create or replace function public.delete_user()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = auth.uid();
$$;

-- Lock the SECURITY DEFINER function to signed-in users only. Must revoke from
-- PUBLIC (not just anon): Postgres grants EXECUTE to PUBLIC by default, and anon
-- inherits it — `revoke ... from anon` alone leaves the function callable by anon.
revoke execute on function public.delete_user() from public, anon;
grant execute on function public.delete_user() to authenticated;
