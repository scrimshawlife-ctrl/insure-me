import { mkdtempSync, chmodSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { describe, expect, it } from 'vitest';

const wrapper = join(process.cwd(), 'scripts/security/pnpm-audit-baseline.mjs');

function runFakePnpm(stdout: string, status = 0) {
  const dir = mkdtempSync(join(tmpdir(), 'insure-me-pnpm-audit-'));
  const bin = join(dir, 'bin');
  mkdirSync(bin);
  const fake = join(bin, 'pnpm');
  writeFileSync(fake, `#!/usr/bin/env node\nprocess.stdout.write(${JSON.stringify(stdout)});\nprocess.exit(${status});\n`);
  chmodSync(fake, 0o755);
  const reportPath = join(dir, 'audit.json');
  const result = spawnSync(process.execPath, [wrapper], { env: { ...process.env, npm_execpath: '', PATH: `${bin}${delimiter}${process.env.PATH}`, PNPM_AUDIT_REPORT_PATH: reportPath }, encoding: 'utf8' });
  return { result, report: JSON.parse(readFileSync(reportPath, 'utf8')), reportText: readFileSync(reportPath, 'utf8') };
}

describe('pnpm audit aggregate wrapper', () => {
  it('passes and emits only aggregate counts when no high production vulnerabilities exist', () => {
    const { result, report } = runFakePnpm(JSON.stringify({ metadata: { vulnerabilities: { critical: 0, high: 0, moderate: 1, low: 2, info: 0 } } }));
    expect(result.status).toBe(0);
    expect(report.verdict).toBe('PASS');
    expect(report.aggregateVulnerabilityCounts).toEqual({ critical: 0, high: 0, moderate: 1, low: 2, info: 0 });
    expect(Object.keys(report)).toEqual(['schemaVersion','contractVersions','verdict','aggregateVulnerabilityCounts','timing','errorCode']);
  });

  it('fails without leaking advisory bodies, package names, endpoints, or errors', () => {
    const raw = { metadata: { vulnerabilities: { critical: 1, high: 1, moderate: 0, low: 0, info: 0 } }, advisories: { '1': { module_name: 'secret-package', url: 'https://example.invalid/advisory', findings: ['raw'] } } };
    const { result, report, reportText } = runFakePnpm(JSON.stringify(raw), 1);
    expect(result.status).toBe(1);
    expect(report.verdict).toBe('FAIL');
    expect(report.aggregateVulnerabilityCounts.critical).toBe(1);
    expect(reportText).not.toContain('secret-package');
    expect(reportText).not.toContain('https://example.invalid');
  });

  it('fails closed when the audit command exits without vulnerability metadata', () => {
    const { result, report } = runFakePnpm(JSON.stringify({ error: 'registry unavailable' }), 1);
    expect(result.status).toBe(1);
    expect(report.verdict).toBe('BLOCKED');
    expect(report.errorCode).toBe('AUDIT_EXECUTION_FAILED');
  });
});
