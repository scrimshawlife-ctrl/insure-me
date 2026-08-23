-- Hardened SECURITY DEFINER functions use pgcrypto from Supabase's trusted extensions schema.
-- Keep `extensions` explicit rather than widening search_path globally.

alter function private.transition_quote_case_with_audit_impl(
  uuid, public.quote_case_state, text, text[]
) set search_path = public, private, extensions;

alter function private.record_consumer_consent_with_audit_impl(
  uuid, uuid, text, public.consent_action, timestamptz, text, text, text
) set search_path = public, private, extensions;

alter function private.create_consumer_quote_case_impl(
  text, uuid, text, text, text
) set search_path = public, private, extensions;

alter function private.upsert_consumer_identity_impl(
  uuid, bytea, text, text, text
) set search_path = public, private, extensions;
