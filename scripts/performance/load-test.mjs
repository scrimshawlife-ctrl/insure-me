import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { performance } from 'node:perf_hooks';

const baseUrl = process.env.LOAD_TEST_BASE_URL ?? 'http://127.0.0.1:3000';
const requestCount = Number.parseInt(process.env.LOAD_TEST_REQUESTS ?? '1000', 10);
const concurrency = Number.parseInt(process.env.LOAD_TEST_CONCURRENCY ?? '20', 10);
const reportPath = process.env.LOAD_TEST_REPORT_PATH ?? 'artifacts/load-test-report-v1.json';
const availabilityTarget = 99.9;
const p95TargetMilliseconds = 750;
const routes = ['/', '/api/health/readiness'];

if (!Number.isSafeInteger(requestCount) || requestCount < 100
  || !Number.isSafeInteger(concurrency) || concurrency < 1 || concurrency > 100
  || concurrency > requestCount) {
  throw new Error('LOAD_TEST_CONFIGURATION_INVALID');
}

async function request(path) {
  const started = performance.now();
  try {
    const response = await fetch(`${baseUrl}${path}`, {
      cache: 'no-store',
      redirect: 'manual',
      signal: AbortSignal.timeout(5_000),
      headers: { 'user-agent': 'insure-me-load-test/reliability-v1' },
    });
    await response.arrayBuffer();
    return { path, status: response.status, durationMilliseconds: performance.now() - started,
      successful: response.status >= 200 && response.status < 400 };
  } catch (error) {
    return { path, status: 0, durationMilliseconds: performance.now() - started,
      successful: false, error: error instanceof Error ? error.name : 'UNKNOWN' };
  }
}

function percentile(values, fraction) {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.ceil(sorted.length * fraction) - 1)];
}

for (let index = 0; index < 20; index += 1) await request(routes[index % routes.length]);

const results = new Array(requestCount);
let nextIndex = 0;
const runStarted = performance.now();
await Promise.all(Array.from({ length: concurrency }, async () => {
  while (true) {
    const index = nextIndex;
    nextIndex += 1;
    if (index >= requestCount) return;
    results[index] = await request(routes[index % routes.length]);
  }
}));
const elapsedMilliseconds = performance.now() - runStarted;

const successful = results.filter((result) => result.successful).length;
const durations = results.map((result) => result.durationMilliseconds);
const availabilityPercent = (successful / requestCount) * 100;
const p95Milliseconds = percentile(durations, 0.95);
const routeSummaries = Object.fromEntries(routes.map((path) => {
  const routeResults = results.filter((result) => result.path === path);
  return [path, {
    requests: routeResults.length,
    successful: routeResults.filter((result) => result.successful).length,
    p95Milliseconds: Number(percentile(routeResults.map((result) => result.durationMilliseconds), 0.95).toFixed(2)),
  }];
}));

const report = {
  schemaVersion: 'load-test-report-v1',
  reliabilityContractVersion: 'reliability-v1',
  profile: { requestCount, concurrency, warmupRequests: 20, timeoutMilliseconds: 5_000, routes },
  targets: { availabilityPercent: availabilityTarget, p95Milliseconds: p95TargetMilliseconds },
  observed: {
    successful, failed: requestCount - successful,
    availabilityPercent: Number(availabilityPercent.toFixed(3)),
    p50Milliseconds: Number(percentile(durations, 0.5).toFixed(2)),
    p95Milliseconds: Number(p95Milliseconds.toFixed(2)),
    p99Milliseconds: Number(percentile(durations, 0.99).toFixed(2)),
    elapsedMilliseconds: Number(elapsedMilliseconds.toFixed(2)),
    requestsPerSecond: Number((requestCount / (elapsedMilliseconds / 1000)).toFixed(2)),
    routes: routeSummaries,
  },
  passed: availabilityPercent >= availabilityTarget && p95Milliseconds <= p95TargetMilliseconds,
};

await mkdir(dirname(reportPath), { recursive: true });
await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
process.stdout.write(`${JSON.stringify(report)}\n`);
if (!report.passed) process.exitCode = 1;
