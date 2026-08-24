-- Trusted privacy application RPCs execute private implementations through
-- public service-role wrappers. The role already has function-level EXECUTE
-- grants, so schema USAGE is required for PostgreSQL to resolve those calls.
grant usage on schema private to service_role;

create or replace function private.prevent_audit_event_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  raise exception using errcode = '22023', message = 'AUDIT_EVENT_IMMUTABLE';
  return null;
end
$$;

revoke all on function private.prevent_audit_event_mutation() from public;

create trigger audit_event_immutable
before update or delete on public.audit_events
for each row execute function private.prevent_audit_event_mutation();
