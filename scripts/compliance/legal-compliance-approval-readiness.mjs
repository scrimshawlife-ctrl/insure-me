#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

const inputPath = process.env.LEGAL_COMPLIANCE_APPROVAL_METADATA_PATH
  ?? 'testdata/legal-compliance/synthetic-ready-metadata-v1.json';
const outputPath = process.env.LEGAL_COMPLIANCE_APPROVAL_REPORT_PATH
  ?? 'artifacts/legal-compliance-approval-readiness-report-v1.json';

const requiredApprovalDomains = [
  'legal-compliance-review',
  'carrier-program-responsibilities',
  'provider-roles-and-contracts',
  'notice-catalog',
  'data-use-matrix',
  'retention-schedule',
];
const requiredControlDomains = [
  'california-insurance-privacy',
  'glba-safeguards',
  'dppa-permissible-purpose',
  'fcra-consumer-reports-and-adverse-action',
  'ccpa-cpra-processing-context',
  'california-rating-and-underwriting',
  'california-breach-and-security',
  'electronic-consent-and-records',
  'transactional-and-marketing-separation',
  'accessibility',
  'privacy-rights-rehearsal',
  'incident-response-exercise',
  'audit-evidence-export',
];
const requiredOpenQuestionBlockers = [
  'Q-001', 'Q-002', 'Q-003', 'Q-004', 'Q-005',
  'Q-006', 'Q-007', 'Q-008', 'Q-009', 'Q-010',
];
const forbiddenKeys = new Set([
  'rawevidence', 'evidencepayload', 'evidencebody', 'noticebody', 'noticetext', 'legalopinion',
  'legalconclusion', 'contractbody', 'reportbody', 'reportbodies', 'providerresponse',
  'carrierresponse', 'findings', 'rawfindings', 'pii', 'person', 'prospect', 'quotecase',
  'driver', 'vehicle', 'name', 'email', 'phone', 'address', 'ssn', 'dob', 'licensenumber',
  'secret', 'secrets', 'token', 'tokens', 'credential', 'credentials', 'password', 'jwt',
  'payload', 'payloads', 'stack', 'stacktrace', 'deadline', 'certification', 'certified',
]);
const reservedOpaqueSentinels = new Set(['UNVERIFIED', 'UNKNOWN', 'BLOCKED', 'NOT_COMPUTABLE']);
const bindingKeys = ['environment', 'deploymentRef', 'tenantConfigurationId', 'tenantId', 'agencyId', 'configurationVersion'];

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
function isSafeOpaque(value) {
  return typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(value);
}
function isValidOpaqueInput(value) {
  return isSafeOpaque(value) && !reservedOpaqueSentinels.has(value.toUpperCase());
}
function safeOpaque(value) {
  return isValidOpaqueInput(value) ? value : 'UNVERIFIED';
}
function containsForbiddenKey(value) {
  if (Array.isArray(value)) return value.some(containsForbiddenKey);
  if (!isPlainObject(value)) return false;
  return Object.entries(value).some(([key, child]) => forbiddenKeys.has(key.toLowerCase()) || containsForbiddenKey(child));
}
function exactKeys(value, keys) {
  return isPlainObject(value)
    && Object.keys(value).length === keys.length
    && Object.keys(value).every((key) => keys.includes(key));
}
function exactNamedEntries(value, names, entryKeys) {
  return Array.isArray(value)
    && value.length === names.length
    && new Set(value.map((entry) => entry?.domain ?? entry?.questionId)).size === names.length
    && value.every((entry) => exactKeys(entry, entryKeys))
    && names.every((name) => value.some((entry) => (entry.domain ?? entry.questionId) === name));
}
function bindingFrom(entry) {
  return Object.fromEntries(bindingKeys.map((key) => [key, safeOpaque(entry?.[key])]));
}
function hasExactSelectedDeploymentBinding(entry, selected) {
  const tenant = selected.tenantConfiguration;
  return entry.environment === selected.environment
    && entry.deploymentRef === selected.deploymentRef
    && entry.tenantConfigurationId === tenant.tenantConfigurationId
    && entry.tenantId === tenant.tenantId
    && entry.agencyId === tenant.agencyId
    && entry.configurationVersion === tenant.configurationVersion;
}
function sanitize(metadata) {
  const selected = isPlainObject(metadata?.selectedDeployment) ? metadata.selectedDeployment : {};
  const tenant = isPlainObject(selected.tenantConfiguration) ? selected.tenantConfiguration : {};
  const approvalByDomain = new Map(Array.isArray(metadata?.approvalDomains)
    ? metadata.approvalDomains.map((entry) => [entry?.domain, entry]) : []);
  const controlByDomain = new Map(Array.isArray(metadata?.controlDomains)
    ? metadata.controlDomains.map((entry) => [entry?.domain, entry]) : []);
  const blockerById = new Map(Array.isArray(metadata?.openQuestionBlockers)
    ? metadata.openQuestionBlockers.map((entry) => [entry?.questionId, entry]) : []);
  return {
    selectedDeployment: {
      environment: safeOpaque(selected.environment),
      deploymentRef: safeOpaque(selected.deploymentRef),
      tenantConfiguration: {
        tenantConfigurationId: safeOpaque(tenant.tenantConfigurationId),
        tenantId: safeOpaque(tenant.tenantId),
        agencyId: safeOpaque(tenant.agencyId),
        configurationVersion: safeOpaque(tenant.configurationVersion),
      },
      exactBinding: selected.exactBinding === true,
    },
    approvalDomains: requiredApprovalDomains.map((domain) => {
      const entry = approvalByDomain.get(domain) ?? {};
      return {
        domain,
        ...bindingFrom(entry),
        ownerRef: safeOpaque(entry.ownerRef),
        authorityRef: safeOpaque(entry.authorityRef),
        evidenceRef: safeOpaque(entry.evidenceRef),
        evidencePresent: entry.evidencePresent === true,
        exactBinding: entry.exactBinding === true,
      };
    }),
    controlDomains: requiredControlDomains.map((domain) => {
      const entry = controlByDomain.get(domain) ?? {};
      return { domain, ...bindingFrom(entry), evidenceRef: safeOpaque(entry.evidenceRef), evidencePresent: entry.evidencePresent === true, exactBinding: entry.exactBinding === true };
    }),
    openQuestionBlockers: requiredOpenQuestionBlockers.map((questionId) => {
      const entry = blockerById.get(questionId) ?? {};
      return {
        questionId,
        ...bindingFrom(entry),
        ownerRef: safeOpaque(entry.ownerRef),
        authorityRef: safeOpaque(entry.authorityRef),
        evidenceRef: safeOpaque(entry.evidenceRef),
        resolvedForSelectedDeployment: entry.resolvedForSelectedDeployment === true,
        exactBinding: entry.exactBinding === true,
      };
    }),
    externalEvidence: {
      selectedDeploymentBindingReceived: metadata?.externalEvidence?.selectedDeploymentBindingReceived === true,
      approvalDomainMetadataReceived: metadata?.externalEvidence?.approvalDomainMetadataReceived === true,
      controlDomainMetadataReceived: metadata?.externalEvidence?.controlDomainMetadataReceived === true,
      openQuestionDecisionMetadataReceived: metadata?.externalEvidence?.openQuestionDecisionMetadataReceived === true,
    },
  };
}
function report(verdict, errorCode, metadata) {
  const clean = sanitize(metadata);
  return {
    schemaVersion: 'legal-compliance-approval-readiness-report-v1',
    contractVersions: { acceptance: 'A-052', task: 'T911' },
    ...clean,
    timing: { producedEpochMs: Date.now() },
    errorCode,
    verdict,
  };
}
function blocked(code, metadata) {
  return report('BLOCKED', code, metadata);
}
function validSelectedDeployment(metadata) {
  const selected = metadata.selectedDeployment;
  const tenant = selected?.tenantConfiguration;
  return exactKeys(selected, ['environment', 'deploymentRef', 'tenantConfiguration', 'exactBinding'])
    && exactKeys(tenant, ['tenantConfigurationId', 'tenantId', 'agencyId', 'configurationVersion'])
    && selected.exactBinding === true
    && [selected.environment, selected.deploymentRef, tenant.tenantConfigurationId, tenant.tenantId, tenant.agencyId, tenant.configurationVersion].every(isValidOpaqueInput);
}
function validate(metadata) {
  if (!isPlainObject(metadata)) return blocked('INVALID_METADATA_SHAPE');
  if (containsForbiddenKey(metadata)) return blocked('FORBIDDEN_RAW_EVIDENCE_KEY', metadata);
  const topKeys = ['schemaVersion', 'selectedDeployment', 'approvalDomains', 'controlDomains', 'openQuestionBlockers', 'externalEvidence'];
  if (!exactKeys(metadata, topKeys)) return blocked('INVALID_TOP_LEVEL_KEYS', metadata);
  if (metadata.schemaVersion !== 'legal-compliance-approval-metadata-v1') return blocked('INVALID_SCHEMA_VERSION', metadata);
  if (!validSelectedDeployment(metadata)) return blocked('MISSING_EXACT_SELECTED_DEPLOYMENT_BINDING', metadata);

  const approvalKeys = ['domain', ...bindingKeys, 'ownerRef', 'authorityRef', 'evidenceRef', 'evidencePresent', 'exactBinding'];
  if (!exactNamedEntries(metadata.approvalDomains, requiredApprovalDomains, approvalKeys)) return blocked('INVALID_APPROVAL_DOMAINS', metadata);
  if (metadata.approvalDomains.some((entry) => !isValidOpaqueInput(entry.ownerRef) || !isValidOpaqueInput(entry.authorityRef) || !isValidOpaqueInput(entry.evidenceRef))) return blocked('INVALID_APPROVAL_REFERENCE', metadata);
  if (metadata.approvalDomains.some((entry) => entry.evidencePresent !== true || entry.exactBinding !== true || !hasExactSelectedDeploymentBinding(entry, metadata.selectedDeployment))) return blocked('MISSING_APPROVAL_DOMAIN_EVIDENCE', metadata);

  const controlKeys = ['domain', ...bindingKeys, 'evidenceRef', 'evidencePresent', 'exactBinding'];
  if (!exactNamedEntries(metadata.controlDomains, requiredControlDomains, controlKeys)) return blocked('INVALID_CONTROL_DOMAINS', metadata);
  if (metadata.controlDomains.some((entry) => !isValidOpaqueInput(entry.evidenceRef))) return blocked('INVALID_CONTROL_EVIDENCE_REFERENCE', metadata);
  if (metadata.controlDomains.some((entry) => entry.evidencePresent !== true || entry.exactBinding !== true || !hasExactSelectedDeploymentBinding(entry, metadata.selectedDeployment))) return blocked('MISSING_CONTROL_DOMAIN_EVIDENCE', metadata);

  const blockerKeys = ['questionId', ...bindingKeys, 'ownerRef', 'authorityRef', 'evidenceRef', 'resolvedForSelectedDeployment', 'exactBinding'];
  if (!exactNamedEntries(metadata.openQuestionBlockers, requiredOpenQuestionBlockers, blockerKeys)) return blocked('INVALID_OPEN_QUESTION_BLOCKERS', metadata);
  if (metadata.openQuestionBlockers.some((entry) => !isValidOpaqueInput(entry.ownerRef) || !isValidOpaqueInput(entry.authorityRef) || !isValidOpaqueInput(entry.evidenceRef))) return blocked('INVALID_OPEN_QUESTION_REFERENCE', metadata);
  if (metadata.openQuestionBlockers.some((entry) => entry.resolvedForSelectedDeployment !== true || entry.exactBinding !== true || !hasExactSelectedDeploymentBinding(entry, metadata.selectedDeployment))) return blocked('UNRESOLVED_OPEN_QUESTION_BLOCKER', metadata);

  if (!exactKeys(metadata.externalEvidence, ['selectedDeploymentBindingReceived', 'approvalDomainMetadataReceived', 'controlDomainMetadataReceived', 'openQuestionDecisionMetadataReceived'])
    || Object.values(metadata.externalEvidence).some((value) => value !== true)) return blocked('MISSING_EXTERNAL_EVIDENCE', metadata);
  return report('READY_FOR_APPROVAL_REVIEW', null, metadata);
}

let result;
try {
  result = validate(JSON.parse(readFileSync(inputPath, 'utf8')));
} catch {
  result = blocked('METADATA_READ_OR_PARSE_FAILED');
}
mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, `${JSON.stringify(result, null, 2)}\n`);
if (result.verdict === 'BLOCKED') process.exitCode = 1;
