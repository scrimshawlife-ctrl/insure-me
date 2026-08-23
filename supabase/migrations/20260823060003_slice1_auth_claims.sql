-- Slice 1 auth-claim contract.
-- Active tenant may be emitted as a root custom claim or in app_metadata by the auth hook/configuration.

create or replace function public.current_tenant_id()
returns uuid
language sql
stable
as $$
  select nullif(
    coalesce(
      auth.jwt() ->> 'tenant_id',
      auth.jwt() -> 'app_metadata' ->> 'active_tenant_id'
    ),
    ''
  )::uuid
$$;

create or replace function public.workforce_mfa_satisfied()
returns boolean
language sql
stable
as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
$$;

create or replace function public.has_tenant_membership(target_tenant uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.workforce_mfa_satisfied()
    and public.current_tenant_id() = target_tenant
    and exists (
      select 1
      from public.agency_users au
      where au.tenant_id = target_tenant
        and au.workforce_identity_id = auth.uid()
        and au.status = 'ACTIVE'
    )
$$;
