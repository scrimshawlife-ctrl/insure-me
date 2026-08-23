begin;
select plan(9);

insert into public.agencies(agency_id,tenant_id,legal_name,display_name)
values('f1000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','Security Baseline','Security');
insert into public.agency_users(agency_user_id,tenant_id,agency_id,workforce_identity_id,status)
values('f2000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f9000000-0000-0000-0000-000000000009','ACTIVE');

select is((select allowed from public.record_workforce_security_signal('f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f9000000-0000-0000-0000-000000000009','PROVIDER_ORDER_ATTEMPT','PROVIDER_ORDER',2,60,'{}')),true,'first attempt is allowed');
select is((select signal_count from public.record_workforce_security_signal('f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f9000000-0000-0000-0000-000000000009','PROVIDER_ORDER_ATTEMPT','PROVIDER_ORDER',2,60,'{}')),2,'counter increments atomically');
select is((select allowed from public.record_workforce_security_signal('f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f9000000-0000-0000-0000-000000000009','PROVIDER_ORDER_ATTEMPT','PROVIDER_ORDER',2,60,'{}')),false,'excessive provider order is denied');
select is((select count(*)::int from public.security_alerts where alert_type='EXCESSIVE_PROVIDER_ORDERS'),1,'excessive order creates one alert');
select is((select allowed from public.record_workforce_security_signal('f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f9000000-0000-0000-0000-000000000009','DENIED_LOOKUP','PROVIDER_ORDER',1,300,array['PURPOSE_NOT_PERMITTED'])),true,'first denied lookup is counted below threshold');
select is((select allowed from public.record_workforce_security_signal('f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f9000000-0000-0000-0000-000000000009','DENIED_LOOKUP','PROVIDER_ORDER',1,300,array['PURPOSE_NOT_PERMITTED'])),false,'repeated denied lookup crosses threshold');
select is((select reason_codes[1] from public.security_alerts where alert_type='REPEATED_DENIED_LOOKUPS'),'PURPOSE_NOT_PERMITTED','alert retains categorized reason only');
select is((select count(*)::int from public.security_alerts),2,'one alert exists per exceeded signal window');
select throws_ok($$select * from public.record_workforce_security_signal('f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000008','PROVIDER_ORDER_ATTEMPT','PROVIDER_ORDER',2,60,'{}')$$,'42501','SECURITY_SIGNAL_ACTOR_INVALID','unknown actor cannot create counters');

select * from finish();
rollback;
