# Open Questions and Decision Gates

## Launch-blocking questions

### Q-001 Initial deployment authority
Which agency or licensed insurance entity will operate the first production deployment, and what external-application, vendor, data-storage, and security requirements apply?

Required evidence: written agency/carrier/program approval where required.

Status: `BLOCKED FOR PRODUCTION / NOT BLOCKING CORE BUILD`.

`D-001` records the operator model as two tenants (Exclusive + Broker) under one human. It does not name or certify the licensed agency or entity.

### Q-002 Data storage boundary
For each configured agency, carrier, and provider, which prospect, MVR, claims, consumer-report, quote, and decision data may be stored, for how long, and in what form?

Status: `BLOCKED FOR PRODUCTION / CONFIGURATION-SPECIFIC`.

### Q-003 Carrier handoff
For the first live carrier, what approved mechanism exists: API, deep link, comparative-rater/AMS bridge, secure export, or manual entry?

Status: `BLOCKED FOR LIVE CARRIER / NOT BLOCKING STUB ADAPTER`.

### Q-004 Required/approved data providers
Which MVR, claims, identity, vehicle, and prefill vendors are contractually available to the operating agency and compatible with the selected carrier/program?

Status: `BLOCKED FOR LIVE DATA / NOT BLOCKING SYNTHETIC ADAPTERS`.

### Q-005 FCRA ownership
For each consumer-report product and carrier workflow, who is the user of the report and who owns adverse-action notice delivery: agency, carrier, platform customer, or another party?

Status: `BLOCKED FOR PRODUCTION`.

### Q-006 Notice ownership
Which privacy/information-practices and report notices are supplied by the operating agency/carrier and which are supplied by Insure Me as a service provider or technology platform?

Status: `BLOCKED FOR PRODUCTION`.

### Q-007 Retention
What retention periods are required or permitted for abandoned quotes, completed quotes, consent evidence, MVR/claims reports, carrier decisions, audit events, and privacy evidence?

Status: `BLOCKED FOR PRODUCTION` pending legal/provider/carrier input.

### Q-008 CCPA/CPRA role
For each processing activity and deployment, is Insure Me acting as service provider/contractor or another role, and which insurance/GLBA exemptions apply to which data?

Status: `LEGAL REVIEW`.

### Q-009 California legislative watch
Before launch, confirm whether any newly enacted California insurance privacy law changes notice, consent, retention, service-provider, correction, automated-decision, or adverse-underwriting requirements.

Status: `WATCH`.

### Q-010 Branding
Will the initial consumer experience be Insure Me-branded, white-labeled for the agency, co-branded, or carrier-branded? What approvals are required for any third-party marks?

Status: `CLOSED` by `D-001`. Exclusive MAY use carrier-shaped branding only with third-party mark approval; until then use a synthetic or agency brand. Broker is agency or Insure Me white-label and MUST NOT use the Allstate mark. Live mark evidence remains a production gate and is not Allstate corporate approval.

### Q-011 Multi-carrier strategy
Will the first production release route to a single configured carrier, allow an agent to choose among carriers, or support comparative quoting through an approved rater/AMS?

Status: `CLOSED` by `D-001`. Exclusive = one configured `CarrierProgram`. Broker = multiple programs allowed. Comparative quoting is not required for MVP and is forbidden on Exclusive.

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

The core build MAY proceed with synthetic data and stub carrier/provider adapters while production-specific external gates remain unresolved.

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
`UNVERIFIED` and `BLOCKED` questions must never be converted into production assumptions merely because an API or technical workaround exists. They also MUST NOT prevent implementation of provider-neutral core capabilities when deterministic synthetic adapters can preserve the boundary.
