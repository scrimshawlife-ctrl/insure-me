-- Harden direct Data API access after Slice 3-7 tables are present.
-- Consumer intake is exposed only through safe projection RPCs.
-- Workforce-derived/configuration tables rely on RLS and therefore require SELECT grants.

revoke select on table
  public.drivers,
  public.vehicles,
  public.coverage_requests
from authenticated;

grant select on table
  public.provider_bindings,
  public.external_requests,
  public.external_reports,
  public.provenance_entries,
  public.underwriting_observations,
  public.data_use_policy_rules,
  public.readiness_issues,
  public.carriers,
  public.carrier_programs,
  public.carrier_program_rating_rules,
  public.rating_inputs,
  public.carrier_submissions,
  public.carrier_decisions
to authenticated;
