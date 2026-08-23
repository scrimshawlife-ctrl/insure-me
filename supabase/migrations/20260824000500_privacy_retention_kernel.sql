-- T113: provider-neutral privacy request and retention policy domain kernel.
-- Retention durations are intentionally configuration data. No production
-- duration is assumed while Q-007 remains blocked for legal/provider review.

create type public.privacy_request_type as enum (
  'ACCESS',
  'CORRECTION',
  'DELETION',
  'RESTRICTION',
  'OPT_OUT'
);

create type public.privacy_request_state as enum (
  'RECEIVED',
  'IDENTITY_VERIFICATION_PENDING',
  'IDENTITY_VERIFIED',
  'APPLICABILITY_REVIEW',
  'IN_PROGRESS',
  'COMPLETED',
  'DENIED',
  'CANCELLED'
);

create type public.privacy_identity_state as enum (
  'NOT_STARTED',
  'PENDING',
  'VERIFIED',
  'FAILED',
  'EXPIRED'
);

create type public.retention_disposition as enum (
  'DELETE',
  'ANONYMIZE',
  'REVIEW'
);

create type public.retention_policy_certification_state as enum (
  'DRAFT',
  'SYNTHETIC',
  'APPROVED',
  'SUSPENDED',
  'RETIRED'
);

alter table public.people
  add constraint people_tenant_agency_person_unique unique (tenant_id, agency_id, person_id);

create table public.privacy_requests (
  privacy_request_id uuid primary key default gen_random_uuid(),
  public_reference uuid not null default gen_random_uuid() unique,
  tenant_id uuid not null,
  agency_id uuid not null,
  request_type public.privacy_request_type not null,
  state public.privacy_request_state not null default 'RECEIVED',
  identity_verification_state public.privacy_identity_state not null default 'NOT_STARTED',
  jurisdiction text not null check (jurisdiction = 'CA'),
  intake_channel text not null check (intake_channel in ('WEB', 'EMAIL', 'PHONE', 'MAIL', 'AGENT', 'OTHER')),
  matched_person_id uuid,
  identity_evidence_ref text,
  applicability_reason_codes text[] not null default '{}',
  policy_version_refs text[] not null default '{}',
  received_at timestamptz not null default now(),
  identity_verified_at timestamptz,
  due_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  foreign key (tenant_id, agency_id, matched_person_id)
    references public.people(tenant_id, agency_id, person_id),
  check (
    (identity_verification_state = 'VERIFIED' and identity_verified_at is not null)
    or (identity_verification_state <> 'VERIFIED' and identity_verified_at is null)
  ),
  check (matched_person_id is null or identity_verification_state = 'VERIFIED'),
  check (completed_at is null or state in ('COMPLETED', 'DENIED', 'CANCELLED'))
);

create table public.retention_policies (
  retention_policy_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  policy_set_id text not null,
  version integer not null check (version > 0),
  data_class text not null check (char_length(trim(data_class)) between 1 and 100),
  jurisdiction text not null check (jurisdiction = 'CA'),
  provider_contract_ref text,
  carrier_program_ref text,
  tenant_role text not null default 'CONTROLLER',
  retention_interval interval,
  disposition public.retention_disposition not null,
  legal_hold_blocks_destructive_disposition boolean not null default true,
  certification_state public.retention_policy_certification_state not null default 'DRAFT',
  legal_authority_refs text[] not null default '{}',
  contract_authority_refs text[] not null default '{}',
  effective_at timestamptz,
  retired_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid,
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  unique (tenant_id, agency_id, policy_set_id, version, data_class, jurisdiction),
  check (retention_interval is null or retention_interval > interval '0 seconds'),
  check (not (certification_state = 'APPROVED' and retention_interval is null)),
  check (certification_state <> 'APPROVED' or cardinality(legal_authority_refs) + cardinality(contract_authority_refs) > 0),
  check (certification_state <> 'APPROVED' or effective_at is not null),
  check (certification_state <> 'APPROVED' or legal_hold_blocks_destructive_disposition),
  check (certification_state <> 'RETIRED' or retired_at is not null)
);

-- Published policy versions retain their legal/contract context. A changed rule
-- is a new version; only operational certification/retirement state may change.
create or replace function private.enforce_retention_policy_version_immutability()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if old.certification_state <> 'DRAFT' and (
    new.tenant_id is distinct from old.tenant_id
    or new.agency_id is distinct from old.agency_id
    or new.policy_set_id is distinct from old.policy_set_id
    or new.version is distinct from old.version
    or new.data_class is distinct from old.data_class
    or new.jurisdiction is distinct from old.jurisdiction
    or new.provider_contract_ref is distinct from old.provider_contract_ref
    or new.carrier_program_ref is distinct from old.carrier_program_ref
    or new.tenant_role is distinct from old.tenant_role
    or new.retention_interval is distinct from old.retention_interval
    or new.disposition is distinct from old.disposition
    or new.legal_hold_blocks_destructive_disposition is distinct from old.legal_hold_blocks_destructive_disposition
    or new.legal_authority_refs is distinct from old.legal_authority_refs
    or new.contract_authority_refs is distinct from old.contract_authority_refs
    or new.effective_at is distinct from old.effective_at
  ) then
    raise exception using errcode = '22023', message = 'RETENTION_POLICY_VERSION_IMMUTABLE';
  end if;
  return new;
end
$$;

revoke all on function private.enforce_retention_policy_version_immutability() from public;

create trigger retention_policy_version_immutability
before update on public.retention_policies
for each row execute function private.enforce_retention_policy_version_immutability();

create index privacy_requests_tenant_state_idx
  on public.privacy_requests (tenant_id, agency_id, state, received_at);

create index retention_policies_lookup_idx
  on public.retention_policies (tenant_id, agency_id, policy_set_id, data_class, jurisdiction, version desc);

alter table public.privacy_requests enable row level security;
alter table public.retention_policies enable row level security;

create policy privacy_requests_admin_select on public.privacy_requests
for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
);

create policy retention_policies_admin_select on public.retention_policies
for select to authenticated using (
  private.has_permission(tenant_id, agency_id, 'POLICY_ADMIN')
  or private.has_permission(tenant_id, agency_id, 'PRIVACY_ADMIN')
);

-- Privacy intake and administrative workflow writes are introduced by T800+
-- through narrow audited RPCs. Direct Data API writes remain closed here.
revoke all on public.privacy_requests from anon, authenticated;
revoke all on public.retention_policies from anon, authenticated;
grant select on public.privacy_requests to authenticated;
grant select on public.retention_policies to authenticated;
