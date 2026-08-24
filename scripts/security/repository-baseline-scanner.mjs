#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, extname, relative, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

const mode = process.argv[2];
const root = resolve(process.env.SECURITY_SCAN_ROOT ?? process.cwd());
const output = process.env.SECURITY_SCAN_REPORT_PATH ?? `artifacts/${mode}-baseline-report-v1.json`;
const schemaVersion = `${mode}-baseline-report-v1`;
const sourceExtensions = new Set(['.js','.jsx','.mjs','.cjs','.ts','.tsx','.json','.yml','.yaml','.toml','.env','.sql','.css','.html','.sh','.bash','.zsh','.py','.example']);
const syntheticAllowance = 'security-scan: allow-synthetic';

function listFiles() {
  const envList = process.env.SECURITY_SCAN_FILE_LIST;
  if (envList) return envList.split('\n').filter(Boolean).map((p) => resolve(root, p));
  const out = execFileSync('git', ['ls-files', '-z'], { cwd: root, encoding: 'utf8' });
  return out.split('\0').filter(Boolean).map((p) => resolve(root, p));
}
function isScannable(file) {
  const rel = relative(root, file).replaceAll('\\\\','/');
  if (!rel || rel.startsWith('node_modules/') || rel.startsWith('.git/') || rel.startsWith('artifacts/')) return false;
  if (rel.includes('pnpm-lock.yaml')) return false;
  const ext = extname(rel).toLowerCase();
  return sourceExtensions.has(ext) || /(^|\/)\.env(\.|$)/.test(rel) || rel.endsWith('Dockerfile');
}
function scan(patterns) {
  const counts = Object.fromEntries(patterns.map((p) => [p.id, 0]));
  let scannedFiles = 0;
  for (const file of listFiles().filter(isScannable)) {
    let text = '';
    try { text = readFileSync(file, 'utf8'); } catch { continue; }
    scannedFiles += 1;
    for (const pattern of patterns) {
      for (const line of text.split(/\r?\n/)) {
        pattern.regex.lastIndex = 0;
        if (pattern.regex.test(line) && !(pattern.allowSynthetic !== false && line.includes(syntheticAllowance))) counts[pattern.id] += 1;
      }
    }
  }
  const findingCount = Object.values(counts).reduce((a, b) => a + b, 0);
  return { scannedFiles, findingCount, counts };
}
function writeReport(verdict, results, errorCode = null) {
  const report = { schemaVersion, contractVersions: { acceptance: 'A-050', task: 'T101' }, verdict, aggregateFindingCount: results.findingCount, aggregateRuleCounts: results.counts, scannedFileCount: results.scannedFiles, timing: { producedEpochMs: Date.now() }, errorCode };
  mkdirSync(dirname(output), { recursive: true });
  writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
  if (verdict !== 'PASS') process.exitCode = 1;
}

const secretPatterns = [
  { id: 'privateKeyBlock', regex: new RegExp('-----' + 'BEGIN [A-Z ]*PRIVATE KEY-----'), allowSynthetic: false },
  { id: 'awsAccessKey', regex: /\bAKIA[0-9A-Z]{16}\b/g },
  { id: 'githubToken', regex: /\bgh[pousr]_[A-Za-z0-9_]{36,}\b/g },
  { id: 'slackToken', regex: /\bxox[baprs]-[A-Za-z0-9-]{20,}\b/g },
  { id: 'stripeSecretKey', regex: /\bsk_(?:live|test)_[A-Za-z0-9]{20,}\b/g },
  { id: 'publicSecretEnvName', regex: /\b(?:NEXT_PUBLIC|PUBLIC|VITE|REACT_APP)_[A-Z0-9_]*(?:SECRET|TOKEN|PASSWORD|PRIVATE_KEY|SERVICE_ROLE)[A-Z0-9_]*\b/g },
];
const sastPatterns = [
  { id: 'evalCall', regex: /\beval\s*\(/g },
  { id: 'newFunction', regex: /\bnew\s+Function\s*\(/g },
  { id: 'dangerouslySetInnerHTML', regex: /\bdangerouslySetInnerHTML\b/g }, // security-scan: allow-synthetic
  { id: 'shellTrue', regex: /\bshell\s*:\s*true\b/g },
  { id: 'tlsBypassEnv', regex: /\bNODE_TLS_REJECT_UNAUTHORIZED\s*=\s*['"]?0['"]?/g },
  { id: 'tlsBypassAgent', regex: /\brejectUnauthorized\s*:\s*false\b/g },
  { id: 'childProcessExec', regex: /\bexecSync?\s*\(/g },
];

if (mode === 'secret') { const results = scan(secretPatterns); writeReport(results.findingCount === 0 ? 'PASS' : 'FAIL', results); }
else if (mode === 'sast') { const results = scan(sastPatterns); writeReport(results.findingCount === 0 ? 'PASS' : 'FAIL', results); }
else { writeReport('BLOCKED', { scannedFiles: 0, findingCount: 0, counts: {} }, 'UNKNOWN_SCAN_MODE'); }
