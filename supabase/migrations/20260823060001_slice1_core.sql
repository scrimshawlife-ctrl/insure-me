-- Slice 1: tenant/security/data kernel
-- Canonical source: specs/001-insurance-quote-platform/data-model.md

create extension if not exists pgcrypto;

create type public.record_status as enum ('DRAFT','ACTIVE','RETIRED');
create type public.quote_case_state as enum (
  'DRAFT','NOTICE_REQUIRED','CONSUMER_INPUT','DATA_ENRICHMENT','REVIEW_REQUIRED',
  'READY_FOR_CARRIER','SUBMITTED_TO_CARRIER','CARRIER_RESPONSE','FOLLOW_UP',
  'CLOSED','ABANDONED','RETENTION_HOLD'
);
create type public.permission_code as enum (
  'CASE_READ','CASE_WRITE','REPORT_RETRIEVE','PRIVACY_ADMIN','EXPORT_DATA',
  'CARRIER_SUBMIT','POLICY_ADMIN','AUDIT_READ','TENANT_ADMIN'
);
create type public.purpose_outcome as enum ('ALLOW','DENY');

create table public.agencies (
  agency_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  legal_name text not null,
  display_name text not null,
  status public.record_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  unique (tenant_id, agency_id)
);

create table public.tenant_configurations (
  tenant_configuration_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  version integer not null check (version > 0),
  status public.record_status not null default 'DRAFT',
  brand_configuration_ref text,
  enabled_jurisdictions text[] not null default array['CA']::text[],
  enabled_product_lines text[] not null default array['PRIVATE_PASSENGER_AUTO']::text[],
  notice_policy_set_id text,
  data_use_policy_set_id text,
  retention_policy_set_id text,
  effective_at timestamptz,
  retired_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid,
  unique (tenant_id, agency_id, version),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id)
);

create table public.roles (
  role_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  name text not null,
  permissions public.permission_code[] not null default '{}',
  created_at timestamptz not null default now(),
  unique (tenant_id, agency_id, name),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id)
);

create table public.agency_users (
  agency_user_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  workforce_identity_id uuid not null,
  status public.record_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  unique (tenant_id, agency_id, workforce_identity_id),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id)
);

create table public.agency_user_roles (
  agency_user_id uuid not null references public.agency_users(agency_user_id) on delete cascade,
  role_id uuid not null references public.roles(role_id) on delete cascade,
  primary key (agency_user_id, role_id)
);

create table public.prospects (
  prospect_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  source_classification text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id)
);

create table public.quote_cases (
  quote_case_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  tenant_configuration_id uuid not null references public.tenant_configurations(tenant_configuration_id),
  tenant_configuration_version integer not null,
  jurisdiction text not null check (jurisdiction = 'CA'),
  product_line text not null check (product_line = 'PRIVATE_PASSENGER_AUTO'),
  source_channel text not null,
  state public.quote_case_state not null default 'DRAFT',
  prospect_id uuid not null references public.prospects(prospect_id),
  assigned_agent_id uuid references public.agency_users(agency_user_id),
  selected_carrier_program_id uuid,
  selected_carrier_program_version integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  unique (tenant_id, quote_case_id),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id)
);

create table public.permissible_purpose_decisions (
  decision_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  quote_case_id uuid not null,
  tenant_configuration_version integer not null,
  actor_id uuid,
  jurisdiction text not null,
  capability text not null,
  purpose_code text not null,
  outcome public.purpose_outcome not null,
  reason_codes text[] not null default '{}',
  policy_version text not null,
  evaluated_at timestamptz not null default now(),
  foreign key (tenant_id, quote_case_id) references public.quote_cases(tenant_id, quote_case_id)
);

create table public.audit_events (
  audit_event_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid,
  quote_case_id uuid,
  event_type text not null,
  actor_id uuid,
  subject_ref text,
  configuration_version_ref text,
  policy_version_refs text[] not null default '{}',
  outcome text not null,
  reason_codes text[] not null default '{}',
  occurred_at timestamptz not null default now(),
  integrity_hash text not null,
  metadata jsonb not null default '{}'::jsonb,
  foreign key (tenant_id, quote_case_id) references public.quote_cases(tenant_id, quote_case_id)
);

create table public.idempotency_keys (
  idempotency_record_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  scope text not null,
  idempotency_key text not null,
  request_hash text not null,
  resource_type text,
  resource_id uuid,
  status text not null check (status in ('CLAIMED','SUCCEEDED','FAILED')),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (tenant_id, scope, idempotency_key)
);

create index quote_cases_tenant_state_idx on public.quote_cases (tenant_id, state, updated_at desc);
create index quote_cases_assigned_agent_idx on public.quote_cases (tenant_id, assigned_agent_id, state);
create index audit_events_case_idx on public.audit_events (tenant_id, quote_case_id, occurred_at desc);
create index purpose_decisions_case_idx on public.permissible_purpose_decisions (tenant_id, quote_case_id, evaluated_at desc);

create or replace function public.has_tenant_membership(target_tenant uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.agency_users au
    where au.tenant_id = target_tenant
      and au.workforce_identity_id = auth.uid()
      and au.status = 'ACTIVE'
  )
$$;

alter table public.agencies enable row level security;
alter table public.tenant_configurations enable row level security;
alter table public.roles enable row level security;
alter table public.agency_users enable row level security;
alter table public.agency_user_roles enable row level security;
alter table public.prospects enable row level security;
alter table public.quote_cases enable row level security;
alter table public.permissible_purpose_decisions enable row level security;
alter table public.audit_events enable row level security;
alter table public.idempotency_keys enable row level security;

create policy agencies_tenant_select on public.agencies
for select using (public.has_tenant_membership(tenant_id));

create policy tenant_configurations_tenant_select on public.tenant_configurations
for select using (public.has_tenant_membership(tenant_id));

create policy roles_tenant_select on public.roles
for select using (public.has_tenant_membership(tenant_id));

create policy agency_users_tenant_select on public.agency_users
for select using (public.has_tenant_membership(tenant_id));

create policy agency_user_roles_tenant_select on public.agency_user_roles
for select using (
  exists (
    select 1
    from public.agency_users au
    where au.agency_user_id = agency_user_roles.agency_user_id
      and public.has_tenant_membership(au.tenant_id)
  )
);

create policy prospects_tenant_all on public.prospects
for all using (public.has_tenant_membership(tenant_id))
with check (public.has_tenant_membership(tenant_id));

create policy quote_cases_tenant_all on public.quote_cases
for all using (public.has_tenant_membership(tenant_id))
with check (public.has_tenant_membership(tenant_id));

create policy purpose_decisions_tenant_all on public.permissible_purpose_decisions
for all using (public.has_tenant_membership(tenant_id))
with check (public.has_tenant_membership(tenant_id));

create policy audit_events_tenant_select on public.audit_events
for select using (public.has_tenant_membership(tenant_id));

create policy idempotency_tenant_all on public.idempotency_keys
for all using (public.has_tenant_membership(tenant_id))
with check (public.has_tenant_membership(tenant_id));

-- Writes to agencies, tenant configuration, roles, membership, and audit are server-controlled.
-- Service-role use is permitted only through trusted application modules that enforce policy first.
