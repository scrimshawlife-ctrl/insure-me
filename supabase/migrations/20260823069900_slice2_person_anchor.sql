-- Canonical Person anchor. Sensitive identity remains in person_private_profiles.
-- This migration intentionally runs before Slice 3, whose Driver.person_id FK targets public.people.

create table public.people (
  person_id uuid primary key,
  tenant_id uuid not null,
  agency_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (person_id) references public.person_private_profiles(person_id) on delete cascade,
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  unique (tenant_id, person_id)
);

-- Backfill any identities created before this migration is applied.
insert into public.people (person_id, tenant_id, agency_id, created_at, updated_at)
select person_id, tenant_id, agency_id, created_at, updated_at
from public.person_private_profiles
on conflict (person_id) do nothing;

create or replace function private.sync_person_anchor_from_private_profile()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  insert into public.people (person_id, tenant_id, agency_id, created_at, updated_at)
  values (new.person_id, new.tenant_id, new.agency_id, new.created_at, new.updated_at)
  on conflict (person_id) do update set
    tenant_id = excluded.tenant_id,
    agency_id = excluded.agency_id,
    updated_at = excluded.updated_at;
  return new;
end
$$;

revoke all on function private.sync_person_anchor_from_private_profile() from public;

create trigger person_private_profile_anchor_sync
  after insert or update of tenant_id, agency_id, updated_at
  on public.person_private_profiles
  for each row execute function private.sync_person_anchor_from_private_profile();

alter table public.people enable row level security;

-- Consumer sessions may never enumerate Person anchors. Workforce users may resolve
-- anchors only inside their active tenant; sensitive attributes remain inaccessible here.
create policy people_workforce_select on public.people
for select to authenticated
using (private.has_tenant_membership(tenant_id));

revoke all on public.people from anon, authenticated;
grant select on public.people to authenticated;
