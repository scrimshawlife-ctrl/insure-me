-- Slice 4: allow the server worker to recover a settled idempotent provider result.

create or replace function public.get_provider_request_result(
  p_external_request_id uuid
) returns table (
  request_status public.external_request_status,
  report_status public.external_report_status,
  provider_request_ref text,
  provider_report_ref text,
  retrieved_at timestamptz,
  normalized_snapshot jsonb,
  warnings text[]
)
language sql
security definer
set search_path = public, private, extensions
as $$
  select
    eq.status,
    er.status,
    eq.provider_request_ref,
    er.provider_report_ref,
    er.retrieved_at,
    er.normalized_snapshot,
    er.warnings
  from public.external_requests eq
  left join lateral (
    select * from public.external_reports x
    where x.external_request_id = eq.external_request_id
    order by x.created_at desc
    limit 1
  ) er on true
  where eq.external_request_id = p_external_request_id;
$$;

revoke all on function public.get_provider_request_result(uuid) from public, anon, authenticated;
grant execute on function public.get_provider_request_result(uuid) to service_role;
