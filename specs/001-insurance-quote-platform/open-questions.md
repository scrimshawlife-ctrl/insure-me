# Open Questions and Decision Gates

## Launch-blocking questions

### Q-001 Allstate external application authority
Can the local Mountain View Allstate agency use an externally hosted consumer intake and underwriting-data orchestration application?

Required evidence: written carrier/agency approval or applicable program documentation.

Status: `BLOCKED`.

### Q-002 Allstate data storage boundary
Which prospect, MVR, claims, consumer-report, quote, and decision data may be stored outside Allstate-controlled systems, for how long, and in what form?

Status: `BLOCKED`.

### Q-003 Carrier handoff
What approved mechanism exists: API, deep link, comparative-rater/import integration, secure export, or manual entry?

Status: `BLOCKED`.

### Q-004 Required/approved data providers
Does Allstate mandate or prohibit specific MVR, claims, identity, vehicle, or prefill vendors?

Status: `BLOCKED`.

### Q-005 FCRA ownership
For each consumer-report product, who is the user of the report and who owns adverse-action notice delivery: agency, Allstate, or another party?

Status: `BLOCKED`.

### Q-006 Notice ownership
Which privacy/information-practices and report notices are supplied by Allstate, which by the agency, and which by Insure Me as a service provider?

Status: `BLOCKED`.

### Q-007 Retention
What retention periods are required or permitted for abandoned quotes, completed quotes, consent evidence, MVR/claims reports, carrier decisions, audit events, and privacy evidence?

Status: `BLOCKED` pending legal/provider/carrier input.

### Q-008 CCPA/CPRA role
For each processing activity, is the platform acting as service provider/contractor or another role, and which insurance/GLBA exemptions apply to which data?

Status: `LEGAL REVIEW`.

### Q-009 California SB 354
What is the enacted/final status and effective date, if any, before launch, and does it change notice, consent, retention, service-provider, correction, or adverse-underwriting requirements?

Status: `WATCH`.

### Q-010 Branding
Can the consumer surface use Allstate name/logo/colors, and what trademark/brand approval is required?

Status: `BLOCKED`.

## Non-blocking technical decisions
- hosting platform;
- managed PostgreSQL provider;
- agency workforce identity provider;
- email/SMS provider;
- queue implementation;
- audit tamper-evidence mechanism;
- field encryption/tokenization library/service;
- responsive web only vs native shell after MVP;
- document rendering/storage vendor.

These SHOULD be decided only after external data/storage/security requirements are known.

## Decision record format
For every resolved question create a decision record containing:
- ID;
- date;
- decision;
- authority/source;
- alternatives considered;
- affected specs;
- implementation consequence;
- security/compliance consequence;
- migration/rollback consequence;
- reviewer/owner.

## Rule
`UNVERIFIED` and `BLOCKED` questions must never be converted into implementation assumptions merely because an API or technical workaround exists.
