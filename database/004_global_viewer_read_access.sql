-- Global read-only access for viewer accounts (parents).
-- Run once after 003_self_signup_and_parent_access.sql.

create or replace function public.is_global_viewer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'viewer' and is_active
  );
$$;

drop policy if exists teams_global_viewer_read on public.teams_v2;
create policy teams_global_viewer_read on public.teams_v2
for select using (public.is_global_viewer());

drop policy if exists students_global_viewer_read on public.students_v2;
create policy students_global_viewer_read on public.students_v2
for select using (public.is_global_viewer());

drop policy if exists sessions_global_viewer_read on public.training_sessions;
create policy sessions_global_viewer_read on public.training_sessions
for select using (public.is_global_viewer());

drop policy if exists records_global_viewer_read on public.training_records_v2;
create policy records_global_viewer_read on public.training_records_v2
for select using (public.is_global_viewer());

