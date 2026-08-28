-- Only administrators may soft-delete or restore training records.
-- Coaches may still correct values and notes for their assigned teams.

create or replace function public.protect_record_deletion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.deleted_at is distinct from old.deleted_at and not public.is_admin() then
    raise exception 'only administrators may delete or restore training records';
  end if;
  return new;
end;
$$;

drop trigger if exists training_record_delete_guard on public.training_records_v2;
create trigger training_record_delete_guard
before update of deleted_at on public.training_records_v2
for each row execute function public.protect_record_deletion();

