#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const output = process.env.PNPM_AUDIT_REPORT_PATH ?? 'artifacts/pnpm-audit-baseline-report-v1.json';
const severities = ['critical', 'high', 'moderate', 'low', 'info'];
const counts = Object.fromEntries(severities.map((s) => [s, 0]));
let verdict = 'PASS';
let errorCode = null;
try {
  const auditArgs = ['audit', '--prod', '--audit-level', 'high', '--json'];
  const result = process.env.npm_execpath
    ? spawnSync(process.execPath, [process.env.npm_execpath, ...auditArgs], { encoding: 'utf8', maxBuffer: 1024 * 1024 * 20 })
    : spawnSync('pnpm', auditArgs, { encoding: 'utf8', maxBuffer: 1024 * 1024 * 20 });
  const text = result.stdout && result.stdout.trim() ? result.stdout : '{}';
  const parsed = JSON.parse(text);
  const source = parsed.metadata?.vulnerabilities ?? parsed.vulnerabilities ?? {};
  if (source && typeof source === 'object') for (const sev of severities) counts[sev] = Number(source[sev] ?? 0) || 0;
  const highPlus = counts.high + counts.critical;
  if (highPlus > 0) verdict = 'FAIL';
  else if (result.error || result.status !== 0) {
    verdict = 'BLOCKED';
    errorCode = 'AUDIT_EXECUTION_FAILED';
  }
} catch {
  verdict = 'BLOCKED';
  errorCode = 'AUDIT_EXECUTION_OR_PARSE_FAILED';
}
const report = { schemaVersion: 'pnpm-audit-baseline-report-v1', contractVersions: { acceptance: 'A-050', task: 'T101' }, verdict, aggregateVulnerabilityCounts: counts, timing: { producedEpochMs: Date.now() }, errorCode };
mkdirSync(dirname(output), { recursive: true });
writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
if (verdict !== 'PASS') process.exitCode = 1;
