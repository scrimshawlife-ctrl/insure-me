# Insure Me Constitution

## 1. Mission
Insure Me is a consumer-first insurance intake and quote-preparation platform for California private-passenger auto insurance. It collects prospect information, retrieves authorized underwriting data through approved providers, normalizes and explains that data, and prepares a quote-ready package for an authorized insurance agent or carrier system.

Insure Me does not independently bind coverage, issue a policy, or determine an authoritative premium unless a carrier expressly authorizes that function.

## 2. Governing principles

### 2.1 Purpose-bound access
Every regulated lookup MUST be attached to a valid insurance transaction. No arbitrary person search is permitted.

A regulated request MUST include a quote case, agency, requesting user or service principal, permissible purpose, provider, jurisdiction, request timestamp, and applicable disclosure or authorization version.

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

### 2.5 Provider independence
Business logic MUST depend on capability interfaces, not provider-specific APIs. Required interfaces include motor-vehicle records, claims history, vehicle data, identity verification, and insurance-history data.

### 2.6 Compliance by construction
Legal and contractual controls MUST be encoded as executable product controls, tests, evidence, and audit events. Compliance MUST NOT exist only as policy text.

### 2.7 Data minimization
The product MUST collect and retain only data necessary for the requested insurance transaction, legal obligations, security, fraud prevention, dispute handling, and documented business operations.

### 2.8 Explainability and correction
When a consumer report, external record, or carrier response materially affects a result, the system MUST preserve the source, reason code, and correction/dispute path needed for legally required notices and human review.

### 2.9 No opaque automated underwriting in MVP
MVP MAY summarize, normalize, detect missing data, and surface observations. MVP MUST NOT autonomously decline, increase premium, reduce coverage, or otherwise take adverse underwriting action.

### 2.10 Security default
Sensitive data MUST be protected in transit and at rest. Production secrets MUST use a managed secret store. Access MUST be least-privilege, authenticated, logged, reviewable, and revocable.

### 2.11 Human authority
An authorized agent remains responsible for completing carrier-controlled workflows until carrier integration explicitly delegates an action to the platform.

### 2.12 Jurisdiction is explicit
Every quote case MUST carry jurisdiction. Provider capability, permitted use, disclosures, retention, and workflow behavior MAY vary by jurisdiction. MVP jurisdiction is California only.

### 2.13 Synthetic data first
Development, demos, CI, screenshots, and automated tests MUST use synthetic fixtures unless a specific production validation requires real data and has documented authorization.

### 2.14 No silent scope expansion
The initial product is California private-passenger auto. Home, renters, life, commercial, claims administration, payments, multi-state support, and independent rating require separate specification changes.

## 3. Decision hierarchy
When requirements conflict, use this order:
1. applicable law and regulation;
2. carrier contractual and product rules;
3. approved provider contract and permissible-use rules;
4. this constitution;
5. product specification;
6. technical implementation preference.

## 4. Change control
A change that affects regulated data access, rating/underwriting use, consumer rights, retention, identity, security, carrier authority, or adverse-action behavior requires:
- a written specification change;
- compliance impact review;
- threat-model review when security boundaries change;
- acceptance criteria;
- regression tests;
- explicit disposition of migration and rollback implications.

## 5. MVP hard stops
Production launch MUST NOT occur until:
- Allstate or the operating carrier confirms the permitted integration and handoff model;
- approved data-provider contracts and credentials exist;
- required privacy and insurance notices are legally reviewed;
- data-processing/vendor agreements are complete where required;
- security controls and incident response are verified;
- consumer-report and adverse-action responsibilities are assigned;
- retention/deletion rules are approved;
- production acceptance criteria pass.
