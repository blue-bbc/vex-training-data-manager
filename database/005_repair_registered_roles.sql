-- Repair roles for users who registered through the app.
-- Admin profiles are never changed by this script.

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, role)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(coalesce(new.email, '用户'), '@', 1)),
    case
      when lower(coalesce(new.raw_user_meta_data ->> 'requested_role', '')) = 'viewer'
        then 'viewer'::public.app_role
      else 'coach'::public.app_role
    end
  )
  on conflict (id) do update set
    display_name = excluded.display_name,
    updated_at = now();
  return new;
end;
$$;

update public.profiles p
set
  role = case
    when lower(coalesce(u.raw_user_meta_data ->> 'requested_role', '')) = 'viewer'
      then 'viewer'::public.app_role
    else 'coach'::public.app_role
  end,
  display_name = coalesce(nullif(u.raw_user_meta_data ->> 'display_name', ''), p.display_name),
  updated_at = now()
from auth.users u
where p.id = u.id
  and p.role <> 'admin'::public.app_role
  and lower(coalesce(u.raw_user_meta_data ->> 'requested_role', '')) in ('coach', 'viewer');

select u.email, p.display_name, p.role, p.is_active
from public.profiles p
join auth.users u on u.id = p.id
order by p.created_at desc;

