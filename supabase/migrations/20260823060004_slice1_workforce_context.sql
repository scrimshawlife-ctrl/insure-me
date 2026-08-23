-- Slice 1 trusted workforce context.

create or replace function public.get_current_workforce_context()
returns table (
  agency_user_id uuid,
  tenant_id uuid,
  agency_id uuid,
  permissions public.permission_code[]
)
language sql
stable
security definer
set search_path = public
as $$
  select
    au.agency_user_id,
    au.tenant_id,
    au.agency_id,
    coalesce(
      array_agg(distinct permission_value) filter (where permission_value is not null),
      '{}'::public.permission_code[]
    ) as permissions
  from public.agency_users au
  left join public.agency_user_roles aur on aur.agency_user_id = au.agency_user_id
  left join public.roles r
    on r.role_id = aur.role_id
   and r.tenant_id = au.tenant_id
   and r.agency_id = au.agency_id
  left join lateral unnest(coalesce(r.permissions, '{}'::public.permission_code[])) as permission_value on true
  where au.workforce_identity_id = auth.uid()
    and au.status = 'ACTIVE'
    and au.tenant_id = public.current_tenant_id()
    and public.workforce_mfa_satisfied()
  group by au.agency_user_id, au.tenant_id, au.agency_id
$$;

revoke all on function public.get_current_workforce_context() from public;
grant execute on function public.get_current_workforce_context() to authenticated;
