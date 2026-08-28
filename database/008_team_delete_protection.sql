-- Only administrators may soft-delete or restore teams.

create or replace function public.protect_team_deletion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.deleted_at is distinct from old.deleted_at and not public.is_admin() then
    raise exception 'only administrators may delete or restore teams';
  end if;
  return new;
end;
$$;

drop trigger if exists team_delete_guard on public.teams_v2;
create trigger team_delete_guard
before update of deleted_at on public.teams_v2
for each row execute function public.protect_team_deletion();

