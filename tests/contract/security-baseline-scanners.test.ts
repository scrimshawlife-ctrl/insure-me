import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { describe, expect, it } from 'vitest';

const scanner = join(process.cwd(), 'scripts/security/repository-baseline-scanner.mjs');

function repo(files: Record<string, string>) {
  const dir = mkdtempSync(join(tmpdir(), 'insure-me-security-scan-'));
  execFileSync('git', ['init'], { cwd: dir, stdio: 'ignore' });
  execFileSync('git', ['config', 'user.email', 'test@example.invalid'], { cwd: dir });
  execFileSync('git', ['config', 'user.name', 'Synthetic Test'], { cwd: dir });
  for (const [name, body] of Object.entries(files)) writeFileSync(join(dir, name), body);
  execFileSync('git', ['add', '.'], { cwd: dir });
  execFileSync('git', ['commit', '-m', 'fixtures'], { cwd: dir, stdio: 'ignore' });
  return dir;
}
function run(mode: 'secret' | 'sast', dir: string) {
  const reportPath = join(dir, `${mode}.json`);
  const result = spawnSync(process.execPath, [scanner, mode], { cwd: dir, env: { ...process.env, SECURITY_SCAN_REPORT_PATH: reportPath }, encoding: 'utf8' });
  const report = JSON.parse(readFileSync(reportPath, 'utf8'));
  return { result, report, reportText: readFileSync(reportPath, 'utf8') };
}

describe('repository-native security baseline scanners', () => {
  it('secret scanner fails on private keys, live token shapes, and public secret env names without leaking material', () => {
    const privateKey = '-----' + 'BEGIN PRIVATE KEY-----';
    const dir = repo({ 'bad.ts': `const a='AKIA1234567890ABCDEF';\nconst b='ghp_abcdefghijklmnopqrstuvwxyzABCDEFGHIJ123456';\nconst c='NEXT_PUBLIC_SECRET_TOKEN';\nconst d=\`${privateKey}\`;\n` }); // security-scan: allow-synthetic
    const { result, report, reportText } = run('secret', dir);
    expect(result.status).toBe(1);
    expect(report.verdict).toBe('FAIL');
    expect(report.aggregateFindingCount).toBeGreaterThanOrEqual(4);
    expect(reportText).not.toContain('AKIA1234567890ABCDEF'); // security-scan: allow-synthetic
    expect(reportText).not.toContain('bad.ts');
    expect(Object.keys(report)).toEqual(['schemaVersion','contractVersions','verdict','aggregateFindingCount','aggregateRuleCounts','scannedFileCount','timing','errorCode']);
  });

  it('SAST scanner fails on high-signal unsafe execution, DOM injection, shell, and TLS bypass patterns', () => {
    const dir = repo({ 'bad.tsx': "eval('1'); new Function('return 1'); const x={dangerouslySetInnerHTML:{__html:'x'}}; spawn('x', [], { shell: true }); process.env.NODE_TLS_REJECT_UNAUTHORIZED='0'; const agent={rejectUnauthorized:false};" }); // security-scan: allow-synthetic
    const { result, report, reportText } = run('sast', dir);
    expect(result.status).toBe(1);
    expect(report.verdict).toBe('FAIL');
    expect(report.aggregateFindingCount).toBeGreaterThanOrEqual(6);
    expect(reportText).not.toContain('bad.tsx');
    expect(reportText).not.toContain("eval('1')"); // security-scan: allow-synthetic
  });

  it('passes clean tracked source and explicitly synthetic fixture placeholders', () => {
    const dir = repo({ 'clean.ts': "export const ok = 'ghp_abcdefghijklmnopqrstuvwxyzABCDEFGHIJ123456'; // security-scan: allow-synthetic\nexport function add(a:number,b:number){ return a+b; }\n" });
    const secret = run('secret', dir);
    const sast = run('sast', dir);
    expect(secret.result.status).toBe(0);
    expect(secret.report.verdict).toBe('PASS');
    expect(sast.result.status).toBe(0);
    expect(sast.report.verdict).toBe('PASS');
  });

  it('does not allow a real-looking token merely because its line says fixture or example', () => {
    const dir = repo({ 'bad.ts': "export const leaked = 'ghp_abcdefghijklmnopqrstuvwxyzABCDEFGHIJ123456'; // synthetic fixture example\n" }); // security-scan: allow-synthetic
    const { result, report } = run('secret', dir);
    expect(result.status).toBe(1);
    expect(report.verdict).toBe('FAIL');
  });
});
