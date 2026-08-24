# Compliance Specification

## Purpose
This document defines the compliance workstream and technical controls for the California MVP. It is an engineering specification, not a substitute for legal advice. Production interpretations require qualified legal/compliance approval.

## Governing compliance domains

### California Insurance Information and Privacy Protection Act / CDI privacy regulations
Applies to insurance institutions, agents, and insurance-support organizations and governs nonpublic personal information in insurance transactions.

Engineering implications:
- versioned privacy/information-practices notices;
- clear acknowledgment evidence for electronic transactions where required;
- limits on collection, use, and disclosure;
- safeguards for nonpublic personal information;
- service-provider confidentiality/data handling obligations;
- consumer access/correction workflows where applicable;
- FCRA protections preserved.

Primary source: California Department of Insurance, Title 10 privacy regulations and Insurance Code sections 791-791.27.

### Gramm-Leach-Bliley Act (GLBA)
The operating insurance licensee may have privacy and safeguarding obligations under GLBA as implemented for insurance by state regulators.

Engineering implications:
- written security program support;
- risk assessment;
- access controls;
- service-provider oversight;
- protection of customer information;
- secure disposal/retention controls.

### Driver's Privacy Protection Act (DPPA)
Motor vehicle record access MUST have a permitted purpose. Insurance underwriting/rating-related use may qualify, but each actual provider request remains subject to provider contract, state-specific restrictions, and purpose controls.

Engineering controls:
- no MVR request without QuoteCase;
- purpose decision record required;
- requesting actor/service principal required;
- subject identity and jurisdiction required;
- provider purpose code mapped to internal purpose;
- audit event before and after execution;
- no arbitrary search UI;
- no bulk prospect lookup;
- fail closed when purpose cannot be established.

Primary source: 18 U.S.C. § 2721 and provider/state restrictions.

### Fair Credit Reporting Act (FCRA)
Consumer reports used for insurance underwriting invoke permissible-purpose and adverse-action obligations. Reports may include driving or claims information depending on the provider and product.

Engineering controls:
- identify which providers/products are CRAs/consumer reports;
- store CRA identity and report metadata;
- establish permissible purpose before ordering;
- preserve source linkage into any materially affected carrier decision;
- support adverse-action notice inputs when consumer-report data contributed;
- expose dispute/correction routing information;
- keep notice ownership configurable between carrier/agency as contracts require;
- do not imply the CRA made the insurance decision.

Primary source: FTC guidance for insurers and FCRA §§ 604/615.

### CCPA / CPRA
Do not assume that all insurance data is categorically outside CCPA/CPRA. Applicability can depend on the entity, processing context, and specific statutory exemptions. Website analytics, advertising identifiers, lead-generation data, and other processing may have different treatment from regulated insurance information.

Engineering controls:
- maintain data inventory by processing purpose and legal regime;
- prohibit underwriting data from advertising/behavioral analytics pipelines;
- maintain privacy-rights intake and applicability decision workflow;
- support data minimization and deletion/restriction subject to legal exceptions;
- maintain vendor/service-provider classifications where applicable;
- keep marketing consent separate from quote processing.

### California insurance rating and underwriting rules
The system MUST distinguish collectable information from rating-permitted information. Carrier-filed/approved rules and California law control premium and eligibility factors.

Engineering controls:
- maintain `DataUsePolicy` per attribute/observation;
- no field becomes `RatingInput` without explicit carrier approval;
- carrier adapter schemas are allowlists;
- no model-generated risk scores;
- no hidden proxy variables;
- document reason-code provenance for carrier decisions when available.

### California breach and security obligations
Exact duties depend on entity and incident facts. The platform MUST support prompt containment, forensic evidence, affected-record identification, legal review, and notification workflows.

Engineering controls:
- security incident runbook;
- event/log retention suitable for investigation;
- encryption and key management;
- least privilege;
- vendor incident contacts;
- breach data inventory/export capability;
- tested revocation and credential rotation.

### Electronic consent / records
Electronic notices, acknowledgments, and authorizations MUST preserve evidence of what version was shown, when, to whom, and what affirmative action occurred. E-SIGN/UETA and insurance-specific rules require legal review for final wording/process.

### TCPA / CAN-SPAM / marketing
Transactional quote communications and marketing are separate purposes.

Controls:
- marketing opt-in state separate from quote consent;
- no marketing requirement as a condition of quote unless lawful and approved;
- SMS workflows record consent source and purpose;
- unsubscribe/stop handling where required;
- suppress marketing after withdrawal.

### Accessibility
Engineering baseline: WCAG 2.2 AA for web/mobile surfaces, including keyboard operation, focus visibility, semantic structure, screen reader labeling, contrast, zoom/reflow, error identification, and accessible authentication.

## Compliance ownership matrix
Each production requirement MUST have one accountable owner:
- Agency/Licensee
- Carrier
- Insure Me platform operator
- Data provider/CRA
- Shared

Unassigned responsibility is a launch blocker.

Key ownership items:
- consumer privacy notice;
- information-practices notice;
- MVR permissible purpose;
- consumer-report permissible purpose;
- investigative consumer report disclosure if applicable;
- adverse-action notice;
- dispute handling;
- privacy-rights response;
- data retention;
- security incident notification;
- carrier rating decision;
- provider report accuracy.

## Data-use matrix requirement
Before production, every material field MUST be cataloged with:
- field/observation name;
- source;
- data category;
- sensitivity;
- purpose;
- jurisdiction;
- collect state;
- agent-display state;
- underwriting-use state;
- rating-use state;
- carrier-only state;
- marketing-use state (default prohibited for underwriting data);
- retention rule;
- legal/contract source;
- owner;
- effective date.

Unknown values default to `DENY` for regulated use.

## Notice and authorization catalog
At minimum, determine whether the workflow requires and who owns:
- California insurance privacy/information practices notice;
- provider/consumer-report disclosure;
- authorization for any report category that requires it;
- electronic communication terms;
- privacy policy/CCPA notice at collection as applicable;
- SMS transactional consent;
- optional marketing consent.

No production copy is final until legal approval is recorded in `NoticeDefinition`.

## Privacy rights workflow
1. request received;
2. no existence disclosure before appropriate verification;
3. identity verification;
4. jurisdiction/applicability determination;
5. locate records across canonical DB, report stores, notification systems, logs where applicable, and downstream vendors;
6. classify exemptions/retention obligations;
7. execute access/correction/deletion/restriction action;
8. propagate to required vendors;
9. verify completion;
10. record response/evidence and close within required SLA.

The system MUST NOT promise deletion when law, contract, fraud/security, or audit obligations require retention.

Execution MUST distinguish immediate local correction/restriction from destructive disposition and downstream propagation. Local correction applies only to requester-maintained data; source-backed reports remain unchanged and must route through the responsible dispute process. A deletion request creates explicit delete-queued and exemption evidence, with processing restricted while retention/legal-hold and downstream completion are resolved.

Downstream completion requires provider-neutral, versioned evidence for every affected target. The system must preserve blocked, retryable-failure, permanent-failure, and completed states rather than treating dispatch as completion. A production propagation binding requires the applicable vendor contract, role, correction/deletion channel, retention terms, and evidence semantics to be approved.

Retention disposition MUST resolve through the active tenant configuration and an exact versioned rule for each queued data class. Scheduler dispatch is not completion. Destructive or anonymizing work requires append-only outcome evidence, must recheck policy state and hold signals at execution time, and must preserve separately exempt audit and external-source evidence. Missing Q-007 production approval remains a deployment blocker and cannot be replaced by a synthetic interval.

Legal-hold authority is never inferred. Placement and release require explicit opaque authority and evidence references from an MFA-authenticated privacy/policy administrator. Holds are scoped to a tenant/agency Person, QuoteCase, or PrivacyRequest; placement and release evidence is append-only. Release removes the active block only after an explicit command and leaves destructive work pending for a fresh retention-policy and hold evaluation.

Record discovery MUST be tenant/agency scoped and must not reveal candidate identities when matching is ambiguous. Access exports MUST use an approved disclosure policy, be encrypted at rest, preserve integrity/version evidence, and use an authenticated secure-delivery path. Synthetic disclosure policy does not establish production legal approval.

## FCRA/adverse-action workflow
1. CarrierDecision or authorized human marks potential adverse action.
2. Determine whether a consumer report contributed partly or wholly.
3. Identify CRA(s) and report(s).
4. Determine responsible notice party.
5. Populate required notice fields and carrier/state additions.
6. Deliver through approved channel.
7. retain delivery evidence per approved schedule.
8. expose dispute route and track consumer follow-up.

MVP MUST NOT infer an adverse action solely from its own readiness status.

## Vendor due diligence requirements
Before production provider use:
- contract/DPA/service-provider terms reviewed;
- permitted purposes documented;
- data fields and jurisdictions documented;
- retention/deletion terms documented;
- subprocessor terms known where required;
- security posture reviewed;
- breach notification terms known;
- credential model documented;
- sandbox vs production separation confirmed;
- audit rights/evidence requirements recorded;
- CRA/FCRA role determined where relevant.

## Regulatory change management
Compliance sources MUST have owner + review cadence. Material legal/provider/carrier changes create a specification issue and block affected behavior until rules are updated and tested.

## Current legal watch item
California SB 354 (2025-2026), the proposed Insurance Consumer Privacy Protection Act, would materially modernize insurance privacy if enacted. As of the latest reviewed legislative material, it was not treated as enacted law in this specification. Track its status before production and update the product if it becomes effective.

## Production compliance gate
`PASS` requires:
- legal/compliance review signed off;
- responsibilities for each enabled carrier program resolved;
- provider roles and contracts resolved;
- notices approved/versioned;
- data-use matrix complete;
- retention schedule complete;
- privacy-rights test passed;
- DPPA unauthorized-lookup tests passed;
- FCRA/adverse-action workflow tested with synthetic data;
- incident response exercised;
- audit evidence export verified.
