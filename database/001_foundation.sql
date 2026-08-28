-- VEX Training Tracker: multi-coach foundation
-- Review on a staging Supabase project before applying to production.

create extension if not exists pgcrypto;

create type public.app_role as enum ('admin', 'coach', 'viewer');
create type public.team_access_role as enum ('owner', 'coach', 'viewer');
create type public.record_mode as enum ('timer', 'score');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  role public.app_role not null default 'coach',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.teams_v2 (
  id uuid primary key default gen_random_uuid(),
  number text not null unique,
  type text not null check (type in ('IQ', 'GO')),
  target_event text,
  is_active boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.team_coaches (
  team_id uuid not null references public.teams_v2(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  access_role public.team_access_role not null default 'coach',
  created_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

create table public.students_v2 (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams_v2(id),
  name text not null,
  role text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.stage_templates_v2 (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  mode public.record_mode not null,
  team_type text check (team_type is null or team_type in ('IQ', 'GO')),
  field_schema jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.training_sessions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams_v2(id),
  template_id uuid references public.stage_templates_v2(id),
  title text,
  training_content text,
  notes text,
  started_at timestamptz not null,
  ended_at timestamptz,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.training_records_v2 (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.training_sessions(id),
  team_id uuid not null references public.teams_v2(id),
  student_id uuid not null references public.students_v2(id),
  round integer not null default 1 check (round > 0),
  value_seconds numeric(10, 3) check (value_seconds is null or value_seconds >= 0),
  value_score numeric(12, 3),
  record_data jsonb not null default '{}'::jsonb,
  notes text,
  client_record_id uuid not null default gen_random_uuid(),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (client_record_id)
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id text not null,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(coalesce(new.email, '教练'), '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

create index team_coaches_user_idx on public.team_coaches(user_id);
create index students_team_idx on public.students_v2(team_id) where deleted_at is null;
create index sessions_team_started_idx on public.training_sessions(team_id, started_at desc) where deleted_at is null;
create index records_session_idx on public.training_records_v2(session_id) where deleted_at is null;
create index records_student_idx on public.training_records_v2(student_id, created_at desc) where deleted_at is null;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active
  );
$$;

create or replace function public.can_access_team(target_team_id uuid, write_access boolean default false)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin() or exists (
    select 1
    from public.team_coaches tc
    join public.profiles p on p.id = tc.user_id
    where tc.team_id = target_team_id
      and tc.user_id = auth.uid()
      and p.is_active
      and (not write_access or tc.access_role in ('owner', 'coach'))
  );
$$;

alter table public.profiles enable row level security;
alter table public.teams_v2 enable row level security;
alter table public.team_coaches enable row level security;
alter table public.students_v2 enable row level security;
alter table public.stage_templates_v2 enable row level security;
alter table public.training_sessions enable row level security;
alter table public.training_records_v2 enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_self_read on public.profiles
for select using (id = auth.uid() or public.is_admin());

create policy profiles_admin_manage on public.profiles
for all using (public.is_admin()) with check (public.is_admin());

create policy teams_authorized_read on public.teams_v2
for select using (public.can_access_team(id));

create policy teams_authorized_write on public.teams_v2
for update using (public.can_access_team(id, true))
with check (public.can_access_team(id, true));

create policy teams_admin_insert on public.teams_v2
for insert with check (public.is_admin());

create policy team_coaches_authorized_read on public.team_coaches
for select using (user_id = auth.uid() or public.can_access_team(team_id));

create policy team_coaches_admin_manage on public.team_coaches
for all using (public.is_admin()) with check (public.is_admin());

create policy students_authorized_read on public.students_v2
for select using (public.can_access_team(team_id));

create policy students_authorized_write on public.students_v2
for all using (public.can_access_team(team_id, true))
with check (public.can_access_team(team_id, true));

create policy templates_authenticated_read on public.stage_templates_v2
for select to authenticated using (is_active or public.is_admin());

create policy templates_admin_manage on public.stage_templates_v2
for all using (public.is_admin()) with check (public.is_admin());

create policy sessions_authorized_read on public.training_sessions
for select using (public.can_access_team(team_id));

create policy sessions_authorized_insert on public.training_sessions
for insert with check (public.can_access_team(team_id, true) and created_by = auth.uid());

create policy sessions_authorized_update on public.training_sessions
for update using (public.can_access_team(team_id, true))
with check (public.can_access_team(team_id, true));

create policy sessions_authorized_delete on public.training_sessions
for delete using (public.is_admin());

create policy records_authorized_read on public.training_records_v2
for select using (public.can_access_team(team_id));

create policy records_authorized_insert on public.training_records_v2
for insert with check (public.can_access_team(team_id, true) and created_by = auth.uid());

create policy records_authorized_update on public.training_records_v2
for update using (public.can_access_team(team_id, true))
with check (public.can_access_team(team_id, true));

create policy records_authorized_delete on public.training_records_v2
for delete using (public.is_admin());

create policy audit_admin_read on public.audit_logs
for select using (public.is_admin());

create policy audit_authenticated_insert on public.audit_logs
for insert to authenticated with check (actor_id = auth.uid());

-- Keep team_id consistent with the selected session and student.
create or replace function public.validate_training_record_team()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  session_team uuid;
  student_team uuid;
begin
  select team_id into session_team from public.training_sessions where id = new.session_id;
  select team_id into student_team from public.students_v2 where id = new.student_id;
  if session_team is null or student_team is null or new.team_id <> session_team or new.team_id <> student_team then
    raise exception 'training record team mismatch';
  end if;
  return new;
end;
$$;

create trigger training_record_team_guard
before insert or update on public.training_records_v2
for each row execute function public.validate_training_record_team();
