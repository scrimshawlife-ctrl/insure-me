import { describe, expect, it } from 'vitest';
import catalogJson from './canonical-synthetic-datasets.v1.json';
import { canonicalSyntheticCatalogSchema } from './schema';

const REQUIRED_DATASET_IDS = [
  'happy-path',
  'provider-no-hit',
  'multiple-drivers',
  'multiple-vehicles',
  'conflicting-records',
  'stale-report',
  'provider-outage',
  'consumer-correction',
  'adverse-action-handoff',
  'privacy-deletion',
  'unauthorized-lookup',
  'carrier-adapter-failure',
] as const;

const catalog = canonicalSyntheticCatalogSchema.parse(catalogJson);
const byId = new Map(catalog.datasets.map((dataset) => [dataset.datasetId, dataset]));

describe('canonical synthetic datasets v1', () => {
  it('contains exactly the required FR-025 scenario set', () => {
    expect([...byId.keys()].sort()).toEqual([...REQUIRED_DATASET_IDS].sort());
  });

  it('uses unique deterministic identifiers and no real email domains', () => {
    const quoteCaseIds = catalog.datasets.map((dataset) => dataset.quoteCase.quoteCaseId);
    expect(new Set(quoteCaseIds).size).toBe(quoteCaseIds.length);

    for (const dataset of catalog.datasets) {
      expect(dataset.seed).toBe(dataset.datasetId);
      expect(dataset.consumer.email.endsWith('@example.invalid')).toBe(true);
      expect(dataset.classification).toBe('SYNTHETIC_TEST_ONLY');
      expect(dataset.jurisdiction).toBe('CA');
      expect(dataset.productLine).toBe('PRIVATE_PASSENGER_AUTO');
    }
  });

  it('covers multi-driver and multi-vehicle cardinality', () => {
    expect(byId.get('multiple-drivers')?.drivers).toHaveLength(2);
    expect(byId.get('multiple-vehicles')?.vehicles).toHaveLength(2);
  });

  it('keeps material conflicts unresolved and blocks carrier submission', () => {
    const dataset = byId.get('conflicting-records');
    expect(dataset?.conflicts).toHaveLength(1);
    expect(dataset?.expected.quoteReadiness).toBe('REVIEW_REQUIRED');
    expect(dataset?.expected.carrierSubmissionAllowed).toBe(false);
    expect(dataset?.expected.blockingReasonCodes).toContain('MATERIAL_CONFLICT_UNRESOLVED');
  });

  it('models provider no-hit, stale, and outage separately', () => {
    expect(byId.get('provider-no-hit')?.expected.providerStatuses.CLAIMS).toBe('NO_HIT');
    expect(byId.get('stale-report')?.expected.providerStatuses.MVR).toBe('STALE');
    expect(byId.get('provider-outage')?.expected.providerStatuses.MVR).toBe('ERROR');
  });

  it('preserves consumer correction provenance', () => {
    const dataset = byId.get('consumer-correction');
    expect(dataset?.corrections).toHaveLength(1);
    expect(dataset?.vehicles[0]?.annualMileage).toBe(7200);
    expect(dataset?.expected.auditEventClasses).toContain('CONSUMER_CORRECTION');
  });

  it('represents adverse action as a handoff, not an Insure Me underwriting decision', () => {
    const dataset = byId.get('adverse-action-handoff');
    expect(dataset?.expected.adverseAction).toEqual({
      triggeredBy: 'RESPONSIBLE_PARTY',
      owner: 'CARRIER',
      noticeInputsRecorded: true,
    });
    expect(dataset?.expected.auditEventClasses).toContain('ADVERSE_ACTION_HANDOFF');
  });

  it('routes privacy deletion through policy evaluation instead of unconditional deletion', () => {
    const dataset = byId.get('privacy-deletion');
    expect(dataset?.privacyActions).toHaveLength(1);
    expect(dataset?.expected.quoteReadiness).toBe('RETENTION_HOLD');
    expect(dataset?.expected.carrierSubmissionAllowed).toBe(false);
  });

  it('blocks unauthorized MVR lookup before provider execution', () => {
    const dataset = byId.get('unauthorized-lookup');
    expect(dataset?.notices.some((notice) => notice.category === 'REPORT_AUTHORIZATION')).toBe(false);
    expect(dataset?.providerRequests).toHaveLength(1);
    expect(dataset?.providerRequests[0]?.expectedExecution).toBe('BLOCKED_PRE_EXECUTION');
    expect(dataset?.expected.providerStatuses.MVR).toBe('BLOCKED');
    expect(dataset?.expected.auditEventClasses).toContain('UNAUTHORIZED_LOOKUP_BLOCKED');
  });

  it('matches synthetic carrier A required-input failure semantics', () => {
    const dataset = byId.get('carrier-adapter-failure');
    expect(dataset?.carrier.variant).toBe('A');
    expect(dataset?.carrier.ratingInputs.map((input) => input.inputKey)).toEqual(['mvr.licenseStatus']);
    expect(dataset?.carrier.expectedStatus).toBe('ERROR');
    expect(dataset?.carrier.expectedReasonCodes).toEqual([
      'MISSING_REQUIRED_INPUT:claims.claimCount',
    ]);
  });

  it('is explicitly forbidden for production use', () => {
    expect(catalog.safety.containsRealPII).toBe(false);
    expect(catalog.safety.allowedEnvironments).toEqual(['local', 'ci', 'staging']);
    expect(catalog.safety.productionUse).toBe('FORBIDDEN');
    expect(catalog.determinism.randomness).toBe('NONE');
  });
});
