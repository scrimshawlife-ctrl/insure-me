-- Slice 2: consumer quote access, versioned notices, and consent evidence.
-- Production legal copy is intentionally not embedded here.

create type public.consumer_access_status as enum ('ACTIVE','REVOKED','EXPIRED');
create type public.notice_status as enum ('DRAFT','SYNTHETIC','APPROVED','RETIRED');
create type public.notice_category as enum (
  'INSURANCE_PRIVACY',
  'CONSUMER_REPORT_DISCLOSURE',
  'REPORT_AUTHORIZATION',
  'ELECTRONIC_COMMUNICATIONS',
  'NOTICE_AT_COLLECTION',
  'SMS_TRANSACTIONAL',
  'MARKETING_OPTIONAL'
);
create type public.consent_action as enum (
  'ACKNOWLEDGE',
  'AUTHORIZE',
  'DECLINE',
  'WITHDRAW',
  'OPT_IN',
  'OPT_OUT'
);

create table public.consumer_quote_access (
  consumer_quote_access_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  quote_case_id uuid not null,
  consumer_identity_id uuid not null,
  status public.consumer_access_status not null default 'ACTIVE',
  expires_at timestamptz not null,
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (quote_case_id, consumer_identity_id),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  foreign key (tenant_id, quote_case_id) references public.quote_cases(tenant_id, quote_case_id)
);

create index consumer_quote_access_identity_idx
  on public.consumer_quote_access (consumer_identity_id, status, expires_at desc);
create index consumer_quote_access_case_idx
  on public.consumer_quote_access (tenant_id, quote_case_id, status);

create table public.notice_definitions (
  notice_definition_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  notice_key text not null,
  version integer not null check (version > 0),
  status public.notice_status not null default 'DRAFT',
  category public.notice_category not null,
  jurisdiction text not null check (jurisdiction = 'CA'),
  product_line text not null check (product_line = 'PRIVATE_PASSENGER_AUTO'),
  title text not null,
  body_markdown text not null,
  content_hash text not null check (length(content_hash) = 64),
  required_for_quote boolean not null default false,
  effective_at timestamptz,
  retired_at timestamptz,
  approved_at timestamptz,
  approved_by uuid,
  created_at timestamptz not null default now(),
  created_by uuid,
  unique (tenant_id, agency_id, notice_key, version),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  check (category <> 'MARKETING_OPTIONAL' or required_for_quote = false)
);

create index notice_definitions_active_idx
  on public.notice_definitions (
    tenant_id, agency_id, jurisdiction, product_line, status, category
  );

create table public.consent_records (
  consent_record_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null,
  quote_case_id uuid not null,
  consumer_identity_id uuid not null,
  subject_ref text not null,
  notice_definition_id uuid not null references public.notice_definitions(notice_definition_id),
  notice_version integer not null,
  notice_content_hash text not null check (length(notice_content_hash) = 64),
  action_type public.consent_action not null,
  presented_at timestamptz not null,
  acted_at timestamptz not null,
  channel text not null,
  evidence_ref text not null,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, quote_case_id, idempotency_key),
  foreign key (tenant_id, agency_id) references public.agencies(tenant_id, agency_id),
  foreign key (tenant_id, quote_case_id) references public.quote_cases(tenant_id, quote_case_id)
);

create index consent_records_case_idx
  on public.consent_records (tenant_id, quote_case_id, acted_at desc);
create index consent_records_notice_idx
  on public.consent_records (notice_definition_id, notice_version);

-- Once a notice is activated as SYNTHETIC or APPROVED, the legal/content identity is immutable.
-- Retirement metadata may change, but modifying content requires a new version.
create or replace function private.enforce_notice_definition_immutability()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if old.status in ('SYNTHETIC','APPROVED','RETIRED') and (
    new.tenant_id is distinct from old.tenant_id
    or new.agency_id is distinct from old.agency_id
    or new.notice_key is distinct from old.notice_key
    or new.version is distinct from old.version
    or new.category is distinct from old.category
    or new.jurisdiction is distinct from old.jurisdiction
    or new.product_line is distinct from old.product_line
    or new.title is distinct from old.title
    or new.body_markdown is distinct from old.body_markdown
    or new.content_hash is distinct from old.content_hash
    or new.required_for_quote is distinct from old.required_for_quote
  ) then
    raise exception using errcode = '22023', message = 'NOTICE_VERSION_IMMUTABLE';
  end if;
  return new;
end
$$;

revoke all on function private.enforce_notice_definition_immutability() from public;

create trigger notice_definition_immutability
before update on public.notice_definitions
for each row execute function private.enforce_notice_definition_immutability();

create or replace function private.has_consumer_quote_access(target_quote_case uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.consumer_quote_access cqa
      where cqa.quote_case_id = target_quote_case
        and cqa.consumer_identity_id = auth.uid()
        and cqa.status = 'ACTIVE'
        and cqa.expires_at > now()
    )
$$;

revoke all on function private.has_consumer_quote_access(uuid) from public;
grant execute on function private.has_consumer_quote_access(uuid) to authenticated;

create or replace function private.required_notices_satisfied(target_quote_case uuid)
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  with case_context as (
    select qc.tenant_id, qc.agency_id, qc.jurisdiction, qc.product_line
    from public.quote_cases qc
    where qc.quote_case_id = target_quote_case
  ), required_notices as (
    select nd.notice_definition_id, nd.category
    from public.notice_definitions nd
    join case_context cc
      on cc.tenant_id = nd.tenant_id
     and cc.agency_id = nd.agency_id
     and cc.jurisdiction = nd.jurisdiction
     and cc.product_line = nd.product_line
    where nd.status in ('SYNTHETIC','APPROVED')
      and nd.required_for_quote
      and nd.category <> 'MARKETING_OPTIONAL'
      and (nd.effective_at is null or nd.effective_at <= now())
      and (nd.retired_at is null or nd.retired_at > now())
  )
  select not exists (
    select 1
    from required_notices rn
    where not exists (
      select 1
      from public.consent_records cr
      where cr.quote_case_id = target_quote_case
        and cr.notice_definition_id = rn.notice_definition_id
        and cr.action_type in ('ACKNOWLEDGE','AUTHORIZE','OPT_IN')
    )
  )
$$;

revoke all on function private.required_notices_satisfied(uuid) from public;

create or replace function public.get_required_notices_for_quote(p_quote_case_id uuid)
returns table (
  notice_definition_id uuid,
  notice_key text,
  version integer,
  category public.notice_category,
  title text,
  body_markdown text,
  content_hash text,
  required_for_quote boolean
)
language sql
stable
security invoker
set search_path = public, private
as $$
  select
    nd.notice_definition_id,
    nd.notice_key,
    nd.version,
    nd.category,
    nd.title,
    nd.body_markdown,
    nd.content_hash,
    nd.required_for_quote
  from public.quote_cases qc
  join public.notice_definitions nd
    on nd.tenant_id = qc.tenant_id
   and nd.agency_id = qc.agency_id
   and nd.jurisdiction = qc.jurisdiction
   and nd.product_line = qc.product_line
  where qc.quote_case_id = p_quote_case_id
    and private.has_consumer_quote_access(qc.quote_case_id)
    and nd.status in ('SYNTHETIC','APPROVED')
    and (nd.effective_at is null or nd.effective_at <= now())
    and (nd.retired_at is null or nd.retired_at > now())
  order by nd.required_for_quote desc, nd.category, nd.notice_key
$$;

revoke all on function public.get_required_notices_for_quote(uuid) from public, anon;
grant execute on function public.get_required_notices_for_quote(uuid) to authenticated;

create or replace function private.record_consumer_consent_with_audit_impl(
  p_quote_case_id uuid,
  p_notice_definition_id uuid,
  p_notice_content_hash text,
  p_action_type public.consent_action,
  p_presented_at timestamptz,
  p_channel text,
  p_evidence_ref text,
  p_idempotency_key text
)
returns public.consent_records
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_case public.quote_cases;
  v_notice public.notice_definitions;
  v_existing public.consent_records;
  v_created public.consent_records;
  v_actor uuid := auth.uid();
  v_integrity_hash text;
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'CONSUMER_AUTHENTICATION_REQUIRED';
  end if;

  select * into v_case
  from public.quote_cases
  where quote_case_id = p_quote_case_id;

  if not found or not private.has_consumer_quote_access(p_quote_case_id) then
    raise exception using errcode = '42501', message = 'CONSUMER_QUOTE_ACCESS_DENIED';
  end if;

  select * into v_notice
  from public.notice_definitions
  where notice_definition_id = p_notice_definition_id
    and tenant_id = v_case.tenant_id
    and agency_id = v_case.agency_id
    and jurisdiction = v_case.jurisdiction
    and product_line = v_case.product_line
    and status in ('SYNTHETIC','APPROVED')
    and (effective_at is null or effective_at <= now())
    and (retired_at is null or retired_at > now());

  if not found then
    raise exception using errcode = '22023', message = 'NOTICE_NOT_AVAILABLE_FOR_QUOTE';
  end if;

  if v_notice.content_hash <> p_notice_content_hash then
    raise exception using errcode = '22023', message = 'NOTICE_CONTENT_HASH_MISMATCH';
  end if;

  if p_presented_at > now() or p_presented_at < now() - interval '24 hours' then
    raise exception using errcode = '22023', message = 'NOTICE_PRESENTATION_TIME_INVALID';
  end if;

  if v_notice.category = 'MARKETING_OPTIONAL' and p_action_type not in ('OPT_IN','OPT_OUT','WITHDRAW') then
    raise exception using errcode = '22023', message = 'MARKETING_CONSENT_ACTION_INVALID';
  end if;

  select * into v_existing
  from public.consent_records
  where tenant_id = v_case.tenant_id
    and quote_case_id = p_quote_case_id
    and idempotency_key = p_idempotency_key;

  if found then
    if v_existing.notice_definition_id <> p_notice_definition_id
      or v_existing.notice_content_hash <> p_notice_content_hash
      or v_existing.action_type <> p_action_type
    then
      raise exception using errcode = '22023', message = 'CONSENT_IDEMPOTENCY_MISMATCH';
    end if;
    return v_existing;
  end if;

  insert into public.consent_records (
    tenant_id,
    agency_id,
    quote_case_id,
    consumer_identity_id,
    subject_ref,
    notice_definition_id,
    notice_version,
    notice_content_hash,
    action_type,
    presented_at,
    acted_at,
    channel,
    evidence_ref,
    idempotency_key
  ) values (
    v_case.tenant_id,
    v_case.agency_id,
    p_quote_case_id,
    v_actor,
    'consumer:' || v_actor::text,
    v_notice.notice_definition_id,
    v_notice.version,
    v_notice.content_hash,
    p_action_type,
    p_presented_at,
    now(),
    p_channel,
    p_evidence_ref,
    p_idempotency_key
  ) returning * into v_created;

  v_integrity_hash := encode(
    digest(
      concat_ws('|',
        v_created.consent_record_id::text,
        v_case.tenant_id::text,
        v_case.quote_case_id::text,
        v_notice.notice_definition_id::text,
        v_notice.version::text,
        v_notice.content_hash,
        p_action_type::text,
        v_created.acted_at::text
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
    v_case.tenant_id,
    v_case.agency_id,
    v_case.quote_case_id,
    'CONSUMER_NOTICE_ACTION',
    v_actor,
    'consumer:' || v_actor::text,
    v_case.tenant_configuration_version::text,
    'SUCCEEDED',
    '{}',
    v_integrity_hash,
    jsonb_build_object(
      'notice_definition_id', v_notice.notice_definition_id,
      'notice_version', v_notice.version,
      'notice_content_hash', v_notice.content_hash,
      'notice_category', v_notice.category,
      'action_type', p_action_type
    )
  );

  return v_created;
end
$$;

revoke all on function private.record_consumer_consent_with_audit_impl(
  uuid, uuid, text, public.consent_action, timestamptz, text, text, text
) from public;
grant execute on function private.record_consumer_consent_with_audit_impl(
  uuid, uuid, text, public.consent_action, timestamptz, text, text, text
) to authenticated;

create or replace function public.record_consumer_consent_with_audit(
  p_quote_case_id uuid,
  p_notice_definition_id uuid,
  p_notice_content_hash text,
  p_action_type public.consent_action,
  p_presented_at timestamptz,
  p_channel text,
  p_evidence_ref text,
  p_idempotency_key text
)
returns public.consent_records
language sql
security invoker
set search_path = public, private
as $$
  select private.record_consumer_consent_with_audit_impl(
    p_quote_case_id,
    p_notice_definition_id,
    p_notice_content_hash,
    p_action_type,
    p_presented_at,
    p_channel,
    p_evidence_ref,
    p_idempotency_key
  )
$$;

revoke all on function public.record_consumer_consent_with_audit(
  uuid, uuid, text, public.consent_action, timestamptz, text, text, text
) from public, anon;
grant execute on function public.record_consumer_consent_with_audit(
  uuid, uuid, text, public.consent_action, timestamptz, text, text, text
) to authenticated;

alter table public.consumer_quote_access enable row level security;
alter table public.notice_definitions enable row level security;
alter table public.consent_records enable row level security;

-- Consumers may read only the QuoteCase to which they have explicit active access.
create policy quote_cases_consumer_select on public.quote_cases
for select to authenticated
using (private.has_consumer_quote_access(quote_case_id));

-- A consumer may inspect only their own active access record. This reveals no other case.
create policy consumer_quote_access_self_select on public.consumer_quote_access
for select to authenticated
using (
  consumer_identity_id = auth.uid()
  and status = 'ACTIVE'
  and expires_at > now()
);

-- Consent records are readable only by the consumer who created them and only while access remains valid.
create policy consent_records_consumer_select on public.consent_records
for select to authenticated
using (
  consumer_identity_id = auth.uid()
  and private.has_consumer_quote_access(quote_case_id)
);

-- Workforce can inspect notice definitions through ordinary tenant + policy administration scope.
create policy notice_definitions_workforce_select on public.notice_definitions
for select to authenticated
using (private.has_tenant_membership(tenant_id));

-- Keep all mutations behind checked server/RPC paths.
revoke all on public.consumer_quote_access from anon, authenticated;
revoke all on public.notice_definitions from anon, authenticated;
revoke all on public.consent_records from anon, authenticated;

grant select on public.consumer_quote_access to authenticated;
grant select on public.consent_records to authenticated;
grant select on public.notice_definitions to authenticated;
