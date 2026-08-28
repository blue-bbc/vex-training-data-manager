-- Run only after the first account has been created successfully.
-- Replace the placeholder email below before execution.

do $$
declare
  target_email text := 'REPLACE_WITH_ADMIN_EMAIL';
  matched_count integer;
begin
  select count(*) into matched_count
  from public.profiles p
  join auth.users u on u.id = p.id
  where lower(u.email) = lower(target_email);

  if matched_count <> 1 then
    raise exception 'Expected exactly one account for %, found %', target_email, matched_count;
  end if;

  update public.profiles p
  set role = 'admin', updated_at = now()
  from auth.users u
  where p.id = u.id
    and lower(u.email) = lower(target_email);
end;
$$;

select u.email, p.display_name, p.role, p.is_active
from public.profiles p
join auth.users u on u.id = p.id
where p.role = 'admin';
