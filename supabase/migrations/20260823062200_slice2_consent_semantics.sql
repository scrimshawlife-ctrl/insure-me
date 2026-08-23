-- Slice 2 consent semantics: acknowledgment is not authorization.

create or replace function private.consent_action_valid_for_category(
  p_category public.notice_category,
  p_action public.consent_action
)
returns boolean
language sql
immutable
security definer
set search_path = public, private
as $$
  select case p_category
    when 'INSURANCE_PRIVACY' then p_action = 'ACKNOWLEDGE'
    when 'CONSUMER_REPORT_DISCLOSURE' then p_action = 'ACKNOWLEDGE'
    when 'REPORT_AUTHORIZATION' then p_action in ('AUTHORIZE','DECLINE','WITHDRAW')
    when 'ELECTRONIC_COMMUNICATIONS' then p_action = 'ACKNOWLEDGE'
    when 'NOTICE_AT_COLLECTION' then p_action = 'ACKNOWLEDGE'
    when 'SMS_TRANSACTIONAL' then p_action in ('OPT_IN','OPT_OUT','WITHDRAW')
    when 'MARKETING_OPTIONAL' then p_action in ('OPT_IN','OPT_OUT','WITHDRAW')
    else false
  end
$$;

revoke all on function private.consent_action_valid_for_category(
  public.notice_category, public.consent_action
) from public;

create or replace function private.consent_action_satisfies_notice(
  p_category public.notice_category,
  p_action public.consent_action
)
returns boolean
language sql
immutable
security definer
set search_path = public, private
as $$
  select case p_category
    when 'INSURANCE_PRIVACY' then p_action = 'ACKNOWLEDGE'
    when 'CONSUMER_REPORT_DISCLOSURE' then p_action = 'ACKNOWLEDGE'
    when 'REPORT_AUTHORIZATION' then p_action = 'AUTHORIZE'
    when 'ELECTRONIC_COMMUNICATIONS' then p_action = 'ACKNOWLEDGE'
    when 'NOTICE_AT_COLLECTION' then p_action = 'ACKNOWLEDGE'
    when 'SMS_TRANSACTIONAL' then p_action = 'OPT_IN'
    when 'MARKETING_OPTIONAL' then false
    else false
  end
$$;

revoke all on function private.consent_action_satisfies_notice(
  public.notice_category, public.consent_action
) from public;

create or replace function private.validate_consent_record_semantics()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_category public.notice_category;
begin
  select category into v_category
  from public.notice_definitions
  where notice_definition_id = new.notice_definition_id;

  if v_category is null then
    raise exception using errcode = '23503', message = 'CONSENT_NOTICE_NOT_FOUND';
  end if;

  if not private.consent_action_valid_for_category(v_category, new.action_type) then
    raise exception using errcode = '22023', message = 'CONSENT_ACTION_INVALID_FOR_NOTICE_CATEGORY';
  end if;

  return new;
end
$$;

revoke all on function private.validate_consent_record_semantics() from public;

drop trigger if exists consent_record_semantics on public.consent_records;
create trigger consent_record_semantics
before insert on public.consent_records
for each row execute function private.validate_consent_record_semantics();

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
        and private.consent_action_satisfies_notice(rn.category, cr.action_type)
    )
  )
$$;
