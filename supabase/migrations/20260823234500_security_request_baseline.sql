-- Durable abuse counters and security alerts. These records are never underwriting inputs.
create table public.security_request_windows (
  security_request_window_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  actor_id uuid not null,
  signal_type text not null check (signal_type in ('PROVIDER_ORDER_ATTEMPT','DENIED_LOOKUP')),
  route_category text not null check (route_category = 'PROVIDER_ORDER'),
  window_started_at timestamptz not null,
  signal_count integer not null default 1 check (signal_count > 0),
  last_seen_at timestamptz not null default now(),
  unique (tenant_id, agency_id, actor_id, signal_type, route_category, window_started_at)
);

create table public.security_alerts (
  security_alert_id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  agency_id uuid not null references public.agencies(agency_id),
  actor_id uuid not null,
  alert_type text not null check (alert_type in ('EXCESSIVE_PROVIDER_ORDERS','REPEATED_DENIED_LOOKUPS')),
  route_category text not null check (route_category = 'PROVIDER_ORDER'),
  threshold integer not null,
  observed_count integer not null,
  reason_codes text[] not null default '{}',
  security_request_window_id uuid not null unique references public.security_request_windows(security_request_window_id),
  created_at timestamptz not null default now()
);

alter table public.security_request_windows enable row level security;
alter table public.security_alerts enable row level security;
create policy security_alerts_audit_read on public.security_alerts for select to authenticated
using (private.has_permission(tenant_id, agency_id, 'AUDIT_READ'));
revoke all on public.security_request_windows, public.security_alerts from anon, authenticated;
grant select on public.security_alerts to authenticated;

create or replace function public.record_workforce_security_signal(
  p_tenant_id uuid, p_agency_id uuid, p_actor_id uuid, p_signal_type text,
  p_route_category text, p_limit integer, p_window_seconds integer, p_reason_codes text[] default '{}'
) returns table(allowed boolean, signal_count integer, alert_created boolean)
language plpgsql security definer set search_path=public,private,extensions
as $$
declare
  v_window_start timestamptz;
  v_window public.security_request_windows;
  v_alert_type text;
begin
  if p_limit < 1 or p_window_seconds < 1 or p_window_seconds > 86400
     or p_signal_type not in ('PROVIDER_ORDER_ATTEMPT','DENIED_LOOKUP') or p_route_category <> 'PROVIDER_ORDER' then
    raise exception using errcode='22023', message='SECURITY_SIGNAL_INVALID';
  end if;
  if not exists(select 1 from public.agency_users where tenant_id=p_tenant_id and agency_id=p_agency_id and workforce_identity_id=p_actor_id and status='ACTIVE') then
    raise exception using errcode='42501', message='SECURITY_SIGNAL_ACTOR_INVALID';
  end if;
  v_window_start := to_timestamp(floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds);
  insert into public.security_request_windows(tenant_id,agency_id,actor_id,signal_type,route_category,window_started_at)
  values(p_tenant_id,p_agency_id,p_actor_id,p_signal_type,p_route_category,v_window_start)
  on conflict(tenant_id,agency_id,actor_id,signal_type,route_category,window_started_at)
  do update set signal_count=public.security_request_windows.signal_count+1,last_seen_at=now()
  returning * into v_window;

  allowed := v_window.signal_count <= p_limit;
  signal_count := v_window.signal_count;
  alert_created := false;
  if not allowed then
    v_alert_type := case when p_signal_type='DENIED_LOOKUP' then 'REPEATED_DENIED_LOOKUPS' else 'EXCESSIVE_PROVIDER_ORDERS' end;
    insert into public.security_alerts(tenant_id,agency_id,actor_id,alert_type,route_category,threshold,observed_count,reason_codes,security_request_window_id)
    values(p_tenant_id,p_agency_id,p_actor_id,v_alert_type,p_route_category,p_limit,v_window.signal_count,coalesce(p_reason_codes,'{}'),v_window.security_request_window_id)
    on conflict(security_request_window_id) do nothing;
    alert_created := found;
  end if;
  return next;
end $$;

revoke all on function public.record_workforce_security_signal(uuid,uuid,uuid,text,text,integer,integer,text[]) from public,anon,authenticated;
grant execute on function public.record_workforce_security_signal(uuid,uuid,uuid,text,text,integer,integer,text[]) to service_role;
