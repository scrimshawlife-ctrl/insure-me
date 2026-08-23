-- Slice 2 hardening: keep privileged notice reads private and advance quote state atomically.

create or replace function private.get_required_notices_for_quote_impl(p_quote_case_id uuid)
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
security definer
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

revoke all on function private.get_required_notices_for_quote_impl(uuid) from public;
grant execute on function private.get_required_notices_for_quote_impl(uuid) to authenticated;

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
  select * from private.get_required_notices_for_quote_impl(p_quote_case_id)
$$;

revoke all on function public.get_required_notices_for_quote(uuid) from public, anon;
grant execute on function public.get_required_notices_for_quote(uuid) to authenticated;

create or replace function private.advance_quote_after_required_notices()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_case public.quote_cases;
  v_integrity_hash text;
begin
  select * into v_case
  from public.quote_cases
  where quote_case_id = new.quote_case_id
  for update;

  if not found or v_case.state <> 'NOTICE_REQUIRED' then
    return new;
  end if;

  if not private.required_notices_satisfied(new.quote_case_id) then
    return new;
  end if;

  update public.quote_cases
  set state = 'CONSUMER_INPUT',
      updated_at = now()
  where quote_case_id = new.quote_case_id;

  v_integrity_hash := encode(
    digest(
      concat_ws('|',
        new.consent_record_id::text,
        v_case.tenant_id::text,
        v_case.quote_case_id::text,
        'REQUIRED_NOTICES_SATISFIED',
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
    v_case.tenant_id,
    v_case.agency_id,
    v_case.quote_case_id,
    'QUOTE_CASE_REQUIRED_NOTICES_SATISFIED',
    new.consumer_identity_id,
    new.subject_ref,
    v_case.tenant_configuration_version::text,
    'SUCCEEDED',
    '{}',
    v_integrity_hash,
    jsonb_build_object('to_state', 'CONSUMER_INPUT')
  );

  return new;
end
$$;

revoke all on function private.advance_quote_after_required_notices() from public;

drop trigger if exists consent_advance_quote_state on public.consent_records;
create trigger consent_advance_quote_state
after insert on public.consent_records
for each row execute function private.advance_quote_after_required_notices();
