-- Run this whole file once in Supabase -> SQL Editor -> New query -> Run.
-- It is safe to run again (it will not delete any data).

-- 1) Japa logs (same as before)
create table if not exists japa_logs (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  day date not null,
  rounds int not null check (rounds between 1 and 64),
  primary key (user_id, day)
);
alter table japa_logs enable row level security;

-- 2) Profiles: one row per user (name, email, daily goal, last login)
create table if not exists profiles (
  user_id uuid primary key references auth.users on delete cascade,
  name text,
  email text,
  goal int not null default 16 check (goal between 1 and 64),
  created_at timestamptz not null default now(),
  last_login timestamptz,
  login_count int not null default 0
);
alter table profiles enable row level security;

-- 3) Login history: one row every time someone signs in (no passwords, ever)
create table if not exists login_events (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users on delete cascade,
  name text,
  email text,
  logged_at timestamptz not null default now()
);
alter table login_events enable row level security;

-- 4) Admins list (nobody can read/write this from the browser)
create table if not exists admins (
  user_id uuid primary key references auth.users on delete cascade
);
alter table admins enable row level security;

create or replace function is_admin() returns boolean
language sql security definer set search_path = public stable as $$
  select exists (select 1 from admins where user_id = auth.uid());
$$;
grant execute on function is_admin() to authenticated;

-- 5) Row-level security policies
drop policy if exists "own rows select" on japa_logs;
drop policy if exists "own rows insert" on japa_logs;
drop policy if exists "own rows update" on japa_logs;
drop policy if exists "own rows delete" on japa_logs;
drop policy if exists "admin read all logs" on japa_logs;
create policy "own rows select" on japa_logs for select using (auth.uid() = user_id);
create policy "own rows insert" on japa_logs for insert with check (auth.uid() = user_id);
create policy "own rows update" on japa_logs for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows delete" on japa_logs for delete using (auth.uid() = user_id);
create policy "admin read all logs" on japa_logs for select using (is_admin());

drop policy if exists "own profile select" on profiles;
drop policy if exists "own profile update" on profiles;
create policy "own profile select" on profiles for select using (auth.uid() = user_id or is_admin());
create policy "own profile update" on profiles for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- users may change only their daily goal
revoke update on profiles from anon, authenticated;
grant update (goal) on profiles to authenticated;

drop policy if exists "admin read logins" on login_events;
create policy "admin read logins" on login_events for select using (is_admin());

-- 6) Auto-create a profile when someone creates an account
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (user_id, name, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)), new.email)
  on conflict (user_id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- Profiles for people who already have accounts
insert into profiles (user_id, name, email, created_at, last_login)
select id, coalesce(raw_user_meta_data->>'name', split_part(email, '@', 1)), email, created_at, last_sign_in_at
from auth.users
on conflict (user_id) do nothing;

-- 7) Called by the app after every successful sign-in
create or replace function record_login() returns void
language plpgsql security definer set search_path = public as $$
declare u record;
begin
  select id, email, created_at, raw_user_meta_data into u from auth.users where id = auth.uid();
  if not found then return; end if;
  insert into profiles (user_id, name, email, created_at, last_login, login_count)
  values (u.id, coalesce(u.raw_user_meta_data->>'name', split_part(u.email, '@', 1)), u.email, u.created_at, now(), 1)
  on conflict (user_id) do update
    set last_login = now(), login_count = profiles.login_count + 1, email = excluded.email;
  insert into login_events (user_id, name, email)
  select user_id, name, email from profiles where user_id = u.id;
end $$;
revoke all on function record_login() from public, anon;
grant execute on function record_login() to authenticated;

-- 8) Lets the sign-in screen say "account doesn't exist" instead of "invalid credentials"
create or replace function email_exists(p_email text) returns boolean
language sql security definer set search_path = public, auth stable as $$
  select exists (select 1 from auth.users where lower(email) = lower(p_email));
$$;
grant execute on function email_exists(text) to anon, authenticated;
