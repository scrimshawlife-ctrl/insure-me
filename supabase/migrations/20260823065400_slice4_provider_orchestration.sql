-- Slice 4: provider orchestration kernel. Provider- and carrier-neutral.

create type public.provider_capability as enum ('IDENTITY','PREFILL','MVR','CLAIMS','VEHICLE');
create type public.external_request_status as enum ('PENDING','RUNNING','SUCCEEDED','FAILED','BLOCKED');
create type public.external_report_status as enum ('SUCCESS','NO_HIT','PARTIAL','STALE','ERROR');

create table public.provider_bindings (
  provider_binding_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  capability public.provider_capability not null,
  adapter_id text not null,
  adapter_version text not null,
  jurisdiction text not null,
  product_line text not null,
  status public.record_status not null default 'ACTIVE',
  requires_report_authorization boolean not null default false,
  purpose_code text not null,
  raw_payload_storage_allowed boolean not null default false,
  created_at timestamptz not null default now(),
  unique (tenant_id, capability, jurisdiction, product_line, adapter_id)
);

create table public.external_requests (
  external_request_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  quote_case_id uuid not null references public.quote_cases(quote_case_id) on delete cascade,
  tenant_configuration_version integer not null,
  provider_binding_id uuid not null references public.provider_bindings(provider_binding_id),
  capability public.provider_capability not null,
  subject_ids uuid[] not null default '{}',
  permissible_purpose_decision_id uuid not null references public.permissible_purpose_decisions(permissible_purpose_decision_id),
  consent_record_ids uuid[] not null default '{}',
  idempotency_key text not null,
  request_hash text not null,
  status public.external_request_status not null default 'PENDING',
  provider_request_ref text,
  failure_reason_codes text[] not null default '{}',
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (tenant_id, provider_binding_id, idempotency_key)
);

create table public.external_reports (
  external_report_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  quote_case_id uuid not null references public.quote_cases(quote_case_id) on delete cascade,
  external_request_id uuid not null references public.external_requests(external_request_id) on delete cascade,
  provider_id text not null,
  provider_product_id text not null,
  provider_report_ref text,
  status public.external_report_status not null,
  retrieved_at timestamptz not null,
  fresh_until timestamptz,
  normalized_snapshot jsonb,
  normalized_version text not null,
  warnings text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table public.provenance_entries (
  provenance_entry_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  quote_case_id uuid not null references public.quote_cases(quote_case_id) on delete cascade,
  external_report_id uuid references public.external_reports(external_report_id) on delete cascade,
  source_type text not null,
  source_id text not null,
  fact_key text not null,
  source_path text,
  source_timestamp timestamptz,
  transformation_version text not null,
  confidence_state text,
  confirmation_state text,
  created_at timestamptz not null default now()
);

create table public.underwriting_observations (
  observation_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  quote_case_id uuid not null references public.quote_cases(quote_case_id) on delete cascade,
  observation_type text not null,
  subject_id uuid,
  normalized_value jsonb not null,
  provenance_entry_ids uuid[] not null default '{}',
  data_use_classification text not null default 'UNCLASSIFIED',
  data_use_policy_version text,
  freshness_state text not null default 'CURRENT',
  conflict_state text not null default 'NONE',
  created_at timestamptz not null default now()
);

alter table public.provider_bindings enable row level security;
alter table public.external_requests enable row level security;
alter table public.external_reports enable row level security;
alter table public.provenance_entries enable row level security;
alter table public.underwriting_observations enable row level security;

create policy provider_bindings_workforce_select on public.provider_bindings
for select to authenticated using (private.has_active_workforce_tenant(tenant_id));
create policy external_requests_workforce_select on public.external_requests
for select to authenticated using (private.has_active_workforce_tenant(tenant_id));
create policy external_reports_workforce_select on public.external_reports
for select to authenticated using (private.has_active_workforce_tenant(tenant_id));
create policy provenance_workforce_select on public.provenance_entries
for select to authenticated using (private.has_active_workforce_tenant(tenant_id));
create policy observations_workforce_select on public.underwriting_observations
for select to authenticated using (private.has_active_workforce_tenant(tenant_id));

revoke insert, update, delete on public.provider_bindings, public.external_requests, public.external_reports, public.provenance_entries, public.underwriting_observations from anon, authenticated;
