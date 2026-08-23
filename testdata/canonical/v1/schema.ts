import { z } from 'zod';

export const CANONICAL_SYNTHETIC_DATASET_VERSION = 'canonical-synthetic-dataset-v1' as const;
export const CANONICAL_SYNTHETIC_CLOCK = '2026-08-23T00:00:00.000Z' as const;

const providerCapability = z.enum(['IDENTITY', 'PREFILL', 'MVR', 'CLAIMS', 'VEHICLE']);
const providerScenario = z.enum(['SUCCESS', 'NO_HIT', 'PARTIAL', 'STALE', 'ERROR']);

const providerRequestSchema = z.object({
  capability: providerCapability,
  scenario: providerScenario,
  subjectIds: z.array(z.string().min(1)).min(1),
  expectedExecution: z.enum(['BLOCKED_PRE_EXECUTION']).optional(),
});

const ratingInputSchema = z.object({
  inputKey: z.string().min(1),
  approvedValue: z.union([z.string(), z.number(), z.boolean(), z.null()]),
  source: z.enum(['PROVIDER', 'CONSUMER', 'AGENT', 'SYSTEM']),
});

export const canonicalSyntheticDatasetSchema = z.object({
  datasetId: z.string().regex(/^[a-z0-9-]+$/),
  name: z.string().min(1),
  description: z.string().min(1),
  schemaVersion: z.literal(CANONICAL_SYNTHETIC_DATASET_VERSION),
  seed: z.string().min(1),
  asOf: z.literal(CANONICAL_SYNTHETIC_CLOCK),
  classification: z.literal('SYNTHETIC_TEST_ONLY'),
  jurisdiction: z.literal('CA'),
  productLine: z.literal('PRIVATE_PASSENGER_AUTO'),
  tenant: z.object({
    tenantId: z.string().min(1),
    agencyId: z.string().min(1),
    configurationVersion: z.string().min(1),
  }),
  quoteCase: z.object({
    quoteCaseId: z.string().min(1),
    sourceChannel: z.literal('WEB'),
    lifecycleState: z.string().min(1),
  }),
  consumer: z.object({
    subjectId: z.string().min(1),
    firstName: z.string().min(1),
    lastName: z.string().min(1),
    dateOfBirth: z.string().min(1),
    email: z.string().email(),
    phone: z.string().min(1),
    address: z.object({
      line1: z.string().min(1),
      city: z.string().min(1),
      state: z.literal('CA'),
      postalCode: z.string().regex(/^\d{5}$/),
    }),
  }),
  notices: z.array(z.object({
    category: z.string().min(1),
    version: z.string().min(1),
    action: z.string().min(1),
    at: z.string().min(1),
  })),
  drivers: z.array(z.object({
    driverId: z.string().min(1),
    subjectId: z.string().min(1),
    relationship: z.string().min(1),
    license: z.object({
      state: z.literal('CA'),
      maskedNumber: z.string().min(1),
      status: z.string().min(1),
    }),
    yearsLicensed: z.number().int().nonnegative(),
  })).min(1),
  vehicles: z.array(z.object({
    vehicleId: z.string().min(1),
    vin: z.string().min(1),
    year: z.number().int(),
    make: z.string().min(1),
    model: z.string().min(1),
    ownership: z.string().min(1),
    usage: z.string().min(1),
    annualMileage: z.number().int().nonnegative(),
    garagingPostalCode: z.string().regex(/^\d{5}$/),
  })).min(1),
  coverageRequest: z.object({
    bodilyInjury: z.string().min(1),
    propertyDamage: z.number().int().positive(),
    collisionDeductible: z.number().int().nonnegative(),
    comprehensiveDeductible: z.number().int().nonnegative(),
  }),
  providerRequests: z.array(providerRequestSchema),
  normalizedFacts: z.record(z.string(), z.unknown()),
  conflicts: z.array(z.record(z.string(), z.unknown())),
  corrections: z.array(z.record(z.string(), z.unknown())),
  privacyActions: z.array(z.record(z.string(), z.unknown())),
  carrier: z.object({
    variant: z.enum(['A', 'B']),
    carrierProgramId: z.string().min(1),
    ratingInputs: z.array(ratingInputSchema),
    expectedStatus: z.enum(['ACCEPTED', 'ERROR', 'NOT_SUBMITTED']),
    expectedReasonCodes: z.array(z.string()).optional(),
  }),
  expected: z.object({
    providerStatuses: z.record(z.string(), z.string()),
    quoteReadiness: z.string().min(1),
    blockingReasonCodes: z.array(z.string()),
    carrierSubmissionAllowed: z.boolean(),
    auditEventClasses: z.array(z.string()).min(1),
    adverseAction: z.record(z.string(), z.unknown()).optional(),
  }),
});

export const canonicalSyntheticCatalogSchema = z.object({
  catalogId: z.literal('insure-me-canonical-synthetic-v1'),
  schemaVersion: z.literal(CANONICAL_SYNTHETIC_DATASET_VERSION),
  generatedAt: z.literal(CANONICAL_SYNTHETIC_CLOCK),
  determinism: z.object({
    clock: z.literal(CANONICAL_SYNTHETIC_CLOCK),
    locale: z.literal('en-US'),
    jurisdiction: z.literal('CA'),
    randomness: z.literal('NONE'),
  }),
  safety: z.object({
    containsRealPII: z.literal(false),
    allowedEnvironments: z.tuple([z.literal('local'), z.literal('ci'), z.literal('staging')]),
    productionUse: z.literal('FORBIDDEN'),
  }),
  datasets: z.array(canonicalSyntheticDatasetSchema).length(12),
});

export type CanonicalSyntheticDataset = z.infer<typeof canonicalSyntheticDatasetSchema>;
export type CanonicalSyntheticCatalog = z.infer<typeof canonicalSyntheticCatalogSchema>;
