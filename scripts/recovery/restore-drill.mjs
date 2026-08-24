import { execFileSync } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { performance } from 'node:perf_hooks';

const container = process.env.RESTORE_DRILL_DB_CONTAINER ?? 'supabase_db_insure-me';
const targetDatabase = 'insure_me_restore_drill';
const dumpPath = '/tmp/insure-me-restore-drill.dump';
const reportPath = process.env.RESTORE_DRILL_REPORT_PATH ?? 'artifacts/restore-drill-report-v1.json';
const fixtureAgencyId = 'd1100000-0000-0000-0000-000000000001';
const fixtureTenantId = 'd1000000-0000-0000-0000-000000000001';
const fixtureAuditId = 'd1200000-0000-0000-0000-000000000001';
const fixtureIntegrityHash = 'd'.repeat(64);

if (!/^supabase_db_[a-zA-Z0-9_-]+$/.test(container)) throw new Error('RESTORE_DRILL_CONTAINER_INVALID');

function docker(...args) {
  return execFileSync('docker', args, { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 }).trim();
}

function sql(database, statement) {
  return docker('exec', container, 'psql', '--username', 'postgres', '--dbname', database,
    '--no-psqlrc', '--tuples-only', '--no-align', '--set', 'ON_ERROR_STOP=1', '--command', statement);
}

function cleanup() {
  try {
    sql('postgres', `delete from public.audit_events where audit_event_id='${fixtureAuditId}'; delete from public.agencies where agency_id='${fixtureAgencyId}'`);
    sql('postgres', `select pg_terminate_backend(pid) from pg_stat_activity where datname='${targetDatabase}' and pid <> pg_backend_pid()`);
    docker('exec', container, 'dropdb', '--username', 'postgres', '--if-exists', targetDatabase);
    docker('exec', container, 'rm', '-f', dumpPath);
  } catch {
    // Cleanup failure is captured without replacing the primary drill verdict.
  }
}

const startedAt = new Date().toISOString();
const started = performance.now();
let dumpSha256 = null;
let verification = {};
let errorCode = null;

try {
  cleanup();
  sql('postgres', `
    delete from public.audit_events where audit_event_id='${fixtureAuditId}';
    delete from public.agencies where agency_id='${fixtureAgencyId}';
    insert into public.agencies (agency_id,tenant_id,legal_name,display_name)
      values ('${fixtureAgencyId}','${fixtureTenantId}','Synthetic Restore Drill Agency','Restore Drill');
    insert into public.audit_events (audit_event_id,tenant_id,agency_id,event_type,actor_id,
      subject_ref,outcome,reason_codes,integrity_hash,metadata)
      values ('${fixtureAuditId}','${fixtureTenantId}','${fixtureAgencyId}','RESTORE_DRILL_SENTINEL',null,
        'recovery:synthetic-sentinel','SUCCEEDED',array['SYNTHETIC_RESTORE_DRILL'],
        '${fixtureIntegrityHash}',jsonb_build_object('fixture','restore-drill-v1'));
  `);

  docker('exec', container, 'pg_dump', '--username', 'postgres', '--dbname', 'postgres',
    '--format', 'custom', '--no-owner',
    '--schema', 'public', '--schema', 'private', '--schema', 'supabase_migrations',
    '--file', dumpPath);
  dumpSha256 = docker('exec', container, 'sha256sum', dumpPath).split(/\s+/)[0];

  docker('exec', container, 'createdb', '--username', 'supabase_admin', '--template', 'template0', targetDatabase);
  sql(targetDatabase, `
    drop schema public cascade;
    create schema auth;
    create function auth.uid() returns uuid language sql stable as 'select null::uuid';
    create function auth.jwt() returns jsonb language sql stable as 'select null::jsonb';
    create schema extensions;
    create extension pgcrypto with schema extensions;
  `);
  docker('exec', container, 'pg_restore', '--username', 'supabase_admin', '--dbname', targetDatabase,
    '--no-owner', '--exit-on-error', dumpPath);

  const values = sql(targetDatabase, `select concat_ws('|',
    (select count(*) from public.agencies where agency_id='${fixtureAgencyId}'),
    (select count(*) from public.audit_events where audit_event_id='${fixtureAuditId}'
      and integrity_hash='${fixtureIntegrityHash}' and metadata->>'fixture'='restore-drill-v1'),
    (select relrowsecurity from pg_class where oid='public.audit_events'::regclass),
    has_table_privilege('authenticated','public.audit_events','UPDATE'),
    to_regprocedure('public.list_retention_policies()') is not null,
    has_function_privilege('authenticated','public.list_retention_policies()','EXECUTE'),
    (select max(version) from supabase_migrations.schema_migrations)
  )`).split('|');

  verification = {
    fixtureAgencyRows: Number(values[0]),
    fixtureAuditRows: Number(values[1]),
    auditRlsEnabled: values[2] === 't',
    authenticatedAuditUpdateAllowed: values[3] === 't',
    policyInspectionRpcPresent: values[4] === 't',
    authenticatedPolicyInspectionAllowed: values[5] === 't',
    latestMigration: values[6],
  };
} catch (error) {
  errorCode = error instanceof Error && error.message.includes('RESTORE_DRILL_CONTAINER_INVALID')
    ? 'RESTORE_DRILL_CONTAINER_INVALID' : 'RESTORE_DRILL_EXECUTION_FAILED';
} finally {
  cleanup();
}

const elapsedMilliseconds = performance.now() - started;
const passed = errorCode === null
  && dumpSha256 !== null
  && verification.fixtureAgencyRows === 1
  && verification.fixtureAuditRows === 1
  && verification.auditRlsEnabled === true
  && verification.authenticatedAuditUpdateAllowed === false
  && verification.policyInspectionRpcPresent === true
  && verification.authenticatedPolicyInspectionAllowed === true
  && verification.latestMigration === '20260824110000'
  && elapsedMilliseconds <= 4 * 60 * 60 * 1000;

const report = {
  schemaVersion: 'restore-drill-report-v1',
  reliabilityContractVersion: 'reliability-v1',
  source: 'isolated-local-supabase-logical-snapshot',
  startedAt,
  completedAt: new Date().toISOString(),
  targets: { rpoMinutes: 5, rtoMinutes: 240 },
  observed: {
    snapshotRecoveryPointMinutes: 0,
    elapsedMilliseconds: Number(elapsedMilliseconds.toFixed(2)),
    dumpSha256,
    verification,
  },
  hostedPitrVerified: false,
  errorCode,
  passed,
};

await mkdir(dirname(reportPath), { recursive: true });
await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
process.stdout.write(`${JSON.stringify(report)}\n`);
if (!passed) process.exitCode = 1;
