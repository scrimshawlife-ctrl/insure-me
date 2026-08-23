# Insure Me Constitution

## 1. Mission
Insure Me is a consumer-first insurance intake and quote-preparation platform for California private-passenger auto insurance. It collects prospect information, retrieves authorized underwriting data through approved providers, normalizes and explains that data, and prepares a quote-ready package for an authorized insurance agency or configured carrier program.

Insure Me does not independently bind coverage, issue a policy, or determine an authoritative premium unless a carrier expressly delegates that authority through a documented and certified program configuration.

## 2. Governing principles

### 2.1 Purpose-bound access
Every regulated lookup MUST be attached to a valid insurance transaction. No arbitrary person search is permitted.

A regulated request MUST include a QuoteCase, tenant/agency, requesting user or service principal, permissible purpose, provider capability, jurisdiction, request timestamp, and applicable disclosure or authorization version.

### 2.2 Provenance is mandatory
Externally derived facts MUST retain source, retrieval time, provider report identifier, jurisdiction, permissible-use classification, and confidence or status where the provider supplies it.

Raw provider facts MUST NOT be silently transformed into carrier rating facts.

### 2.3 Separate collectability from use
For every material data attribute, the system MUST distinguish:
- may collect;
- may display to an agent;
- may use for underwriting;
- may use for rating;
- carrier-controlled use;
- prohibited use.

Availability from an API does not establish legal or contractual permission to use the data.

### 2.4 Carrier authority controls rating
Carrier-approved rating, underwriting, eligibility, binding, and policy-issuance rules are authoritative. Insure Me MUST NOT substitute its own actuarial or underwriting logic for a carrier-controlled decision.

Carrier-specific requirements MUST enter the system through versioned CarrierProgram configuration and adapter-boundary mappings, not through carrier-name branching in the canonical domain.

### 2.5 Provider independence
Business logic MUST depend on capability interfaces, not provider-specific APIs. Required interfaces include motor-vehicle records, claims history, vehicle data, identity verification, prefill, and insurance-history data.

### 2.6 Carrier independence
Core business logic MUST depend on CarrierProgram capability descriptors and CarrierAdapter interfaces, not carrier names, portals, or proprietary field layouts.

Adding or replacing a carrier MUST NOT require changes to canonical QuoteCase, Person, Driver, Vehicle, ExternalReport, UnderwritingObservation, RatingInput, CarrierSubmission, or CarrierDecision semantics solely to satisfy that carrier.

### 2.7 Tenant isolation
Every QuoteCase, regulated request, provider binding, carrier program, credential, policy reference, and workforce action MUST resolve to a trusted tenant/agency context.

Cross-tenant data access, configuration leakage, credential reuse, or existence disclosure is prohibited.

### 2.8 Compliance by construction
Legal and contractual controls MUST be encoded as executable product controls, tests, evidence, and audit events. Compliance MUST NOT exist only as policy text.

### 2.9 Data minimization
The product MUST collect and retain only data necessary for the requested insurance transaction, legal obligations, security, fraud prevention, dispute handling, and documented business operations.

### 2.10 Explainability and correction
When a consumer report, external record, or carrier response materially affects a result, the system MUST preserve the source, reason code, and correction/dispute path needed for legally required notices and human review.

### 2.11 No opaque automated underwriting in MVP
MVP MAY summarize, normalize, detect missing data, calculate workflow readiness, and surface observations. MVP MUST NOT autonomously decline, increase premium, reduce coverage, or otherwise take adverse underwriting action.

### 2.12 Security default
Sensitive data MUST be protected in transit and at rest. Production secrets MUST use a managed secret store. Access MUST be least-privilege, authenticated, logged, reviewable, and revocable.

### 2.13 Human authority
An authorized agent remains responsible for completing carrier-controlled workflows until a certified CarrierProgram explicitly delegates an action to the platform.

### 2.14 Jurisdiction is explicit
Every QuoteCase MUST carry jurisdiction. Provider capability, permitted use, disclosures, retention, and workflow behavior MAY vary by jurisdiction. MVP jurisdiction is California only.

### 2.15 Synthetic data first
Development, demos, CI, screenshots, and automated tests MUST use deterministic synthetic fixtures unless a specific production validation requires real data and has documented authorization.

The complete core workflow MUST be buildable and acceptable without live carrier or consumer-report credentials.

### 2.16 No silent scope expansion
The initial product is California private-passenger auto. Home, renters, life, commercial, claims administration, payments, multi-state support, and independent rating require separate specification changes.

Multiple tenant configurations and multiple carrier adapters are architectural requirements, not product-line or jurisdiction expansion. Initial production deployment MAY enable only one tenant and one live carrier program.

## 3. Decision hierarchy
When requirements conflict, use this order:
1. applicable law and regulation;
2. carrier contractual and product rules for the selected CarrierProgram;
3. approved provider contract and permissible-use rules;
4. this constitution;
5. product specification;
6. technical implementation preference.

## 4. Change control
A change that affects regulated data access, rating/underwriting use, consumer rights, retention, identity, tenant isolation, security, carrier authority, provider semantics, or adverse-action behavior requires:
- a written specification change;
- compliance impact review;
- threat-model review when security boundaries change;
- acceptance criteria;
- regression tests;
- explicit disposition of migration and rollback implications;
- traceability updates across affected specification artifacts.

## 5. Core-build gate
The synthetic core MAY be declared accepted when:
- all P0 CORE acceptance criteria pass;
- deterministic provider adapters execute the required provider-capability paths;
- StubCarrierAdapter executes the complete carrier handoff path;
- tenant isolation and carrier/provider portability tests pass;
- no live consumer-report or carrier credential is required.

## 6. Production hard stops
Production launch MUST NOT occur until the exact deployment configuration has documented evidence for:
- operating tenant/agency/entity authority and deployment requirements;
- at least one certified live CarrierProgram and permitted handoff model;
- each enabled regulated data-provider contract, capability, and credential;
- legally reviewed privacy, insurance, consumer-report, and authorization notices as applicable;
- data-processing/vendor agreements where required;
- security controls, threat model, incident response, and recovery procedures;
- consumer-report, dispute, and adverse-action responsibility assignment;
- approved data-use and retention/deletion rules;
- exact versioned TenantConfiguration, provider bindings, CarrierPrograms, policies, and adapters included in release evidence;
- all P0 PRODUCTION acceptance criteria passing for that configuration.

Unknown or future providers and carriers MUST remain disabled and MUST NOT block synthetic core implementation.