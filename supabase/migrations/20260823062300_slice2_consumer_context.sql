-- Slice 2: trusted consumer context for one QuoteCase.

create or replace function private.get_consumer_quote_context_impl(p_quote_case_id uuid)
returns table (
  quote_case_id uuid,
  tenant_id uuid,
  agency_id uuid,
  access_expires_at timestamptz
)
language sql
stable
security definer
set search_path = public, private
as $$
  select
    cqa.quote_case_id,
    cqa.tenant_id,
    cqa.agency_id,
    cqa.expires_at
  from public.consumer_quote_access cqa
  where cqa.quote_case_id = p_quote_case_id
    and cqa.consumer_identity_id = auth.uid()
    and cqa.status = 'ACTIVE'
    and cqa.expires_at > now()
$$;

revoke all on function private.get_consumer_quote_context_impl(uuid) from public;
grant execute on function private.get_consumer_quote_context_impl(uuid) to authenticated;

create or replace function public.get_consumer_quote_context(p_quote_case_id uuid)
returns table (
  quote_case_id uuid,
  tenant_id uuid,
  agency_id uuid,
  access_expires_at timestamptz
)
language sql
stable
security invoker
set search_path = public, private
as $$
  select * from private.get_consumer_quote_context_impl(p_quote_case_id)
$$;

revoke all on function public.get_consumer_quote_context(uuid) from public, anon;
grant execute on function public.get_consumer_quote_context(uuid) to authenticated;
