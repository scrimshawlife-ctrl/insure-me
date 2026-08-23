-- Slice 2: server-only quote creation resolves tenant from an approved host mapping.

create table public.tenant_hosts (
  tenant_host_id uuid primary key default gen_random_uuid(),
  hostname text not null,
  tenant_id uuid not null,
  agency_id uuid not null,
  tenant_configuration_id uuid not null references public.tenant_configurations(tenant_configuration_id),
  tenant_configuration_version integer not null check (tenant_configuration_version > 0),
  consumer_access_hours integer not null default 24 check (consumer_access_hours between 1 and 168),
  status public.record_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  unique (hostname),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id)
);

create index tenant_hosts_tenant_idx
  on public.tenant_hosts (tenant_id, agency_id, status);

alter table public.tenant_hosts enable row level security;

-- No anon/authenticated table grants. Tenant host resolution is server-only.
revoke all on public.tenant_hosts from anon, authenticated;

create or replace function private.create_consumer_quote_case_impl(
  p_hostname text,
  p_consumer_identity_id uuid,
  p_jurisdiction text,
  p_product_line text,
  p_source_channel text
)
returns table (
  quote_case_id uuid,
  state public.quote_case_state,
  next_action text,
  access_expires_at timestamptz
)
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_host public.tenant_hosts;
  v_config public.tenant_configurations;
  v_prospect_id uuid;
  v_quote_case_id uuid;
  v_expires_at timestamptz;
  v_integrity_hash text;
begin
  if p_consumer_identity_id is null then
    raise exception using errcode = '22023', message = 'CONSUMER_IDENTITY_REQUIRED';
  end if;

  select * into v_host
  from public.tenant_hosts
  where hostname = lower(split_part(trim(p_hostname), ':', 1))
    and status = 'ACTIVE';

  if not found then
    raise exception using errcode = '22023', message = 'TENANT_HOST_NOT_CONFIGURED';
  end if;

  select * into v_config
  from public.tenant_configurations
  where tenant_configuration_id = v_host.tenant_configuration_id
    and tenant_id = v_host.tenant_id
    and agency_id = v_host.agency_id
    and version = v_host.tenant_configuration_version
    and status = 'ACTIVE';

  if not found then
    raise exception using errcode = '22023', message = 'TENANT_CONFIGURATION_NOT_ACTIVE';
  end if;

  if not p_jurisdiction = any(v_config.enabled_jurisdictions) then
    raise exception using errcode = '22023', message = 'JURISDICTION_NOT_ENABLED';
  end if;

  if not p_product_line = any(v_config.enabled_product_lines) then
    raise exception using errcode = '22023', message = 'PRODUCT_LINE_NOT_ENABLED';
  end if;

  insert into public.prospects (
    tenant_id,
    agency_id,
    source_classification
  ) values (
    v_host.tenant_id,
    v_host.agency_id,
    p_source_channel
  ) returning prospect_id into v_prospect_id;

  insert into public.quote_cases (
    tenant_id,
    agency_id,
    tenant_configuration_id,
    tenant_configuration_version,
    jurisdiction,
    product_line,
    source_channel,
    state,
    prospect_id
  ) values (
    v_host.tenant_id,
    v_host.agency_id,
    v_host.tenant_configuration_id,
    v_host.tenant_configuration_version,
    p_jurisdiction,
    p_product_line,
    p_source_channel,
    'DRAFT',
    v_prospect_id
  ) returning public.quote_cases.quote_case_id into v_quote_case_id;

  v_expires_at := now() + make_interval(hours => v_host.consumer_access_hours);

  insert into public.consumer_quote_access (
    tenant_id,
    agency_id,
    quote_case_id,
    consumer_identity_id,
    status,
    expires_at,
    last_verified_at
  ) values (
    v_host.tenant_id,
    v_host.agency_id,
    v_quote_case_id,
    p_consumer_identity_id,
    'ACTIVE',
    v_expires_at,
    now()
  );

  v_integrity_hash := encode(
    digest(
      concat_ws('|',
        v_host.tenant_id::text,
        v_quote_case_id::text,
        p_consumer_identity_id::text,
        'QUOTE_CASE_CREATED',
        clock_timestamp()::text
      ),
      'sha256'
    ),
    'hex'
  );

  insert into public.audit_events (
    tenant_id,
    agency_id,
    quote_case_id,
    event_type,
    actor_id,
    subject_ref,
    configuration_version_ref,
    outcome,
    reason_codes,
    integrity_hash,
    metadata
  ) values (
    v_host.tenant_id,
    v_host.agency_id,
    v_quote_case_id,
    'QUOTE_CASE_CREATED',
    p_consumer_identity_id,
    'consumer:' || p_consumer_identity_id::text,
    v_host.tenant_configuration_version::text,
    'SUCCEEDED',
    '{}',
    v_integrity_hash,
    jsonb_build_object(
      'jurisdiction', p_jurisdiction,
      'product_line', p_product_line,
      'source_channel', p_source_channel
    )
  );

  return query
  select v_quote_case_id, 'DRAFT'::public.quote_case_state, 'IDENTITY'::text, v_expires_at;
end
$$;

revoke all on function private.create_consumer_quote_case_impl(text, uuid, text, text, text) from public;
grant execute on function private.create_consumer_quote_case_impl(text, uuid, text, text, text) to service_role;

create or replace function public.create_consumer_quote_case(
  p_hostname text,
  p_consumer_identity_id uuid,
  p_jurisdiction text,
  p_product_line text,
  p_source_channel text
)
returns table (
  quote_case_id uuid,
  state public.quote_case_state,
  next_action text,
  access_expires_at timestamptz
)
language sql
security invoker
set search_path = public, private
as $$
  select * from private.create_consumer_quote_case_impl(
    p_hostname,
    p_consumer_identity_id,
    p_jurisdiction,
    p_product_line,
    p_source_channel
  )
$$;

revoke all on function public.create_consumer_quote_case(text, uuid, text, text, text)
from public, anon, authenticated;
grant execute on function public.create_consumer_quote_case(text, uuid, text, text, text)
to service_role;
