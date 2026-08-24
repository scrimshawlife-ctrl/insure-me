# User Flows and UX Specification

## UX objective
Make insurance intake feel like verification, not interrogation. The consumer should provide the minimum necessary information, confirm safe prefill, resolve exceptions, and understand what happens next.

## Visual direction
- modern financial-service clarity;
- mobile-first consumer flow;
- desktop/tablet-first agent workspace;
- progressive disclosure;
- high contrast and readable typography;
- no dark patterns;
- plain-language explanations;
- explicit data-source and privacy context where it matters;
- no gamified risk scoring.

## Consumer flow A: new quote
1. Landing page states the agency, product, jurisdiction, and approximate process.
2. CTA: `Start my auto quote`.
3. Collect name, contact, address, and only identity attributes required for the next step.
4. Present privacy/information-practices notice and report disclosure sequence.
5. Capture acknowledgment/authorization.
6. Run approved prefill/identity checks.
7. Show vehicle candidates as cards: confirm/edit/remove/add.
8. Show driver candidates: confirm/edit/remove/add.
9. Collect missing driver/vehicle details.
10. Collect coverage preferences and effective-date intent.
11. Trigger eligible provider enrichment.
12. If enrichment is still running, show neutral progress without exposing provider internals.
13. Present review screen with consumer-provided and confirmed facts.
14. Consumer submits intake.
15. Show clear next state: agent review, carrier quote handoff, or missing-information request.

## Consumer flow B: no prefill hit
The experience MUST degrade gracefully:
- explain that records could not be prefilled;
- allow manual entry;
- do not imply the consumer did anything wrong;
- do not expose provider error codes;
- continue quote if legally/operationally possible.

## Consumer flow C: conflict
If external data conflicts with user input:
- do not silently overwrite;
- show the consumer only data they are permitted to see;
- ask for confirmation/correction where appropriate;
- route sensitive report disputes to the correct process;
- create a ReadinessIssue if agent review is required.

## Consumer flow D: save/resume
- issue secure expiring resume mechanism;
- no sensitive data in link URL;
- re-authenticate after configured risk/time threshold;
- preserve consent evidence and state-machine position.

## Consumer flow E: privacy request
1. Privacy center entry point.
2. Request type selection.
3. Contact information.
4. Identity verification.
5. Controlled tenant-scoped record discovery after verification.
6. Ambiguous or no-match results route to applicability review without candidate disclosure.
7. Request tracking ID and requester-safe status.
8. Access export is delivered through an authenticated no-store download and audited.
9. Other actions continue through the approved correction/deletion/restriction workflow.
10. Corrections apply only to requester-maintained protected data; source-backed disputes are routed separately.
11. Deletion/restriction shows processing state while exemption, retention, or downstream work remains, without promising immediate erasure.
12. Downstream targets remain opaque to the requester; status shows aggregate completion only.
13. Failed or unconfigured propagation stays in progress for controlled retry or compliance review.

## Agent workspace
### Queue
Columns/filters SHOULD include:
- consumer name;
- QuoteCase ID;
- state;
- assigned agent;
- quote age;
- readiness percent/completion state;
- blocking issue count;
- provider status summary;
- last activity.

No risk score column.

### Quote detail layout
Recommended information architecture:
1. Header: prospect, jurisdiction, state, assignment, last update.
2. Readiness: completeness and blocking issues.
3. Drivers.
4. Vehicles.
5. Coverage request.
6. External report status.
7. Underwriting observations.
8. Conflicts/missing data.
9. Carrier handoff.
10. Audit/provenance drawer.

### Provenance interaction
Any externally derived fact SHOULD expose:
- source provider/product;
- retrieved date;
- report/reference ID where display is permitted;
- source status;
- whether consumer confirmed/corrected it;
- use classification visible to authorized staff when useful.

### Provider refresh
Refresh button appears only if:
- caller has permission;
- case state permits it;
- purpose remains valid;
- provider contract permits refresh;
- freshness window allows it;
- required notice/authorization remains valid.

Otherwise show a reason, not a disabled mystery button.

## Admin UX
### Users
Invite/deactivate users, assign roles, view MFA state, revoke sessions.

### Integrations
Show provider/carrier connection state without displaying secrets. Configuration changes require step-up authentication and audit.

### Notices
List notice definitions, versions, effective dates, approval status. Production cannot activate an unapproved notice.

### Data policy
Authorized reviewer can inspect the data-use matrix and retention policies. Changes require controlled deployment/versioning.

### Privacy requests
Queue with request type, verified state, due date, scope, exceptions, downstream completion, evidence.

Deletion remains `IN_PROGRESS` while a policy, interval, hold signal, review, failure, local disposition item, or downstream target is unresolved. The authenticated internal worker returns aggregate status only. Completed identity disposition destroys protected lookup/key material; consumer-input anonymization removes direct identifiers while exempt audit and external-source evidence remains intact.

### Audit
Search by QuoteCase, actor, event type, provider, result, time range. Sensitive details remain permission-filtered.

## Accessibility requirements
- all flows keyboard operable;
- semantic labels and landmarks;
- visible focus;
- no color-only status meaning;
- error summary + field-level errors;
- minimum target sizes appropriate for touch;
- 200% zoom/reflow support;
- screen-reader announcement of async state changes;
- accessible authentication alternatives where required;
- PDF/notices delivered in accessible form where generated.

## Plain-language copy principles
Use:
- `We found two vehicles. Confirm which ones belong on this quote.`
- `We need your permission before requesting this report.`
- `Your quote is being reviewed by an agent.`

Avoid:
- `Risk profile generated.`
- `AI determined...`
- `We pulled everything about you.`
- unexplained abbreviations such as MVR/CRA in consumer-facing copy.

## UX acceptance measures
- mobile consumer flow can be completed without horizontal scrolling;
- no screen requires understanding insurance jargon without explanation;
- consumer can identify what information is editable;
- consumer can distinguish transactional consent from optional marketing consent;
- agent can identify why a case is blocked in one view;
- agent can trace each material external observation to a source in <=2 interactions;
- accessibility automated + manual tests pass approved baseline.
