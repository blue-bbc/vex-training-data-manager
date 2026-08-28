-- Self-registration and parent-to-student access.
-- Run once in Supabase SQL Editor after 001_foundation.sql.

create table if not exists public.parent_student_access (
  parent_user_id uuid not null references public.profiles(id) on delete cascade,
  student_id uuid not null references public.students_v2(id) on delete cascade,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  primary key (parent_user_id, student_id)
);

alter table public.parent_student_access enable row level security;

drop policy if exists parent_access_self_read on public.parent_student_access;
create policy parent_access_self_read on public.parent_student_access
for select using (parent_user_id = auth.uid() or public.is_admin());

drop policy if exists parent_access_admin_manage on public.parent_student_access;
create policy parent_access_admin_manage on public.parent_student_access
for all using (public.is_admin()) with check (public.is_admin());

-- A registering user may request coach or viewer. Admin can still change roles later.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested public.app_role;
begin
  requested := case
    when new.raw_user_meta_data ->> 'requested_role' = 'viewer' then 'viewer'::public.app_role
    else 'coach'::public.app_role
  end;

  insert into public.profiles (id, display_name, role)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(coalesce(new.email, '用户'), '@', 1)),
    requested
  );
  return new;
end;
$$;

-- Parents only receive read access to explicitly assigned students.
drop policy if exists teams_parent_read on public.teams_v2;
create policy teams_parent_read on public.teams_v2
for select using (exists (
  select 1
  from public.students_v2 s
  join public.parent_student_access psa on psa.student_id = s.id
  where s.team_id = teams_v2.id and psa.parent_user_id = auth.uid()
));

drop policy if exists students_parent_read on public.students_v2;
create policy students_parent_read on public.students_v2
for select using (exists (
  select 1 from public.parent_student_access psa
  where psa.student_id = students_v2.id and psa.parent_user_id = auth.uid()
));

drop policy if exists records_parent_read on public.training_records_v2;
create policy records_parent_read on public.training_records_v2
for select using (exists (
  select 1 from public.parent_student_access psa
  where psa.student_id = training_records_v2.student_id and psa.parent_user_id = auth.uid()
));

drop policy if exists sessions_parent_read on public.training_sessions;
create policy sessions_parent_read on public.training_sessions
for select using (exists (
  select 1
  from public.training_records_v2 r
  join public.parent_student_access psa on psa.student_id = r.student_id
  where r.session_id = training_sessions.id and psa.parent_user_id = auth.uid()
));

create index if not exists parent_student_access_parent_idx
on public.parent_student_access(parent_user_id);
