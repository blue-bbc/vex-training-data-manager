-- Full-field lineup support.
-- One score stays in training_records_v2; this table links every student who
-- actually participated in that round, preventing duplicated team scores.

create table if not exists public.training_record_participants (
  record_id uuid not null references public.training_records_v2(id) on delete cascade,
  team_id uuid not null references public.teams_v2(id),
  student_id uuid not null references public.students_v2(id),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  primary key (record_id, student_id)
);

create index if not exists record_participants_student_idx
on public.training_record_participants(student_id, created_at desc);

create index if not exists record_participants_team_idx
on public.training_record_participants(team_id, created_at desc);

alter table public.training_record_participants enable row level security;

drop policy if exists record_participants_authorized_read on public.training_record_participants;
create policy record_participants_authorized_read
on public.training_record_participants for select
using (public.can_access_team(team_id) or public.is_global_viewer());

drop policy if exists record_participants_authorized_insert on public.training_record_participants;
create policy record_participants_authorized_insert
on public.training_record_participants for insert
with check (public.can_access_team(team_id, true) and created_by = auth.uid());

drop policy if exists record_participants_authorized_update on public.training_record_participants;
create policy record_participants_authorized_update
on public.training_record_participants for update
using (public.can_access_team(team_id, true))
with check (public.can_access_team(team_id, true));

drop policy if exists record_participants_admin_delete on public.training_record_participants;
create policy record_participants_admin_delete
on public.training_record_participants for delete
using (public.is_admin());

grant select, insert, update, delete on public.training_record_participants to authenticated;

create or replace function public.validate_training_record_participant()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  record_team uuid;
  student_team uuid;
begin
  select team_id into record_team from public.training_records_v2 where id = new.record_id;
  select team_id into student_team from public.students_v2 where id = new.student_id;
  if record_team is null or student_team is null or new.team_id <> record_team or new.team_id <> student_team then
    raise exception 'training record participant team mismatch';
  end if;
  return new;
end;
$$;

drop trigger if exists training_record_participant_guard on public.training_record_participants;
create trigger training_record_participant_guard
before insert or update on public.training_record_participants
for each row execute function public.validate_training_record_participant();

-- Save the full-field score and all round participants atomically. If any
-- participant link fails, the score insert is rolled back as well.
create or replace function public.create_field_training_record(
  p_session_id uuid,
  p_team_id uuid,
  p_score numeric,
  p_participant_ids uuid[],
  p_created_by uuid,
  p_round integer default 1
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  new_record_id uuid;
begin
  if coalesce(array_length(p_participant_ids, 1), 0) = 0 then
    raise exception 'at least one participant is required';
  end if;
  if p_score is null or p_score < 0 then
    raise exception 'score must be zero or greater';
  end if;

  insert into public.training_records_v2 (
    session_id, team_id, student_id, round, value_seconds, value_score,
    record_data, created_by
  ) values (
    p_session_id, p_team_id, p_participant_ids[1], p_round, null, p_score,
    jsonb_build_object(
      'mode', 'score',
      'duration_limit_seconds', 60,
      'participant_ids', to_jsonb(p_participant_ids)
    ),
    p_created_by
  )
  returning id into new_record_id;

  insert into public.training_record_participants (record_id, team_id, student_id, created_by)
  select new_record_id, p_team_id, participant_id, p_created_by
  from unnest(p_participant_ids) as participant_id;

  return new_record_id;
end;
$$;

grant execute on function public.create_field_training_record(uuid, uuid, numeric, uuid[], uuid, integer) to authenticated;
