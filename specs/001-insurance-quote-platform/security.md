# Security Specification

## Security objective
Protect consumer, agency, carrier, and provider data while preventing unauthorized lookup, lateral access, credential abuse, silent data exfiltration, and integrity failures in quote preparation.

## Threat model
Primary threats:
- arbitrary or curiosity-driven lookup of people;
- stolen agent credentials;
- session theft;
- provider credential theft;
- cross-agency data exposure;
- insecure direct object reference;
- PII leakage through logs/analytics/errors;
- malicious or compromised vendor response;
- report tampering or provenance loss;
- forged consent/authorization evidence;
- duplicate/replayed provider orders;
- duplicate carrier submissions;
- admin privilege escalation;
- bulk export/exfiltration;
- insecure support access;
- non-production copying of real data;
- dependency/supply-chain compromise.

## Identity
### Workforce
- centralized identity provider;
- MFA required;
- phishing-resistant MFA preferred for administrators;
- SSO supported when agency/carrier requires it;
- short session lifetime for privileged actions;
- step-up authentication for exports, role changes, provider credentials, or privacy administration.

### Consumer
- secure magic link, OTP, or equivalent session bootstrap;
- short-lived, scoped quote session;
- re-verification for high-risk corrections or privacy requests;
- no sensitive identifiers in URL fragments/query parameters.

### Service principals
- workload identities preferred over static long-lived API keys;
- least-privilege scopes;
- independent rotation and revocation;
- environment isolation.

## Authorization
Use RBAC plus contextual rules:
- agency scope;
- case relationship/assignment where appropriate;
- jurisdiction;
- capability;
- purpose;
- case lifecycle state;
- admin elevation.

Every sensitive object fetch MUST authorize the object, not only the route.

## Sensitive data controls
High sensitivity includes DOB, driver's license number, MVR contents, claims/consumer-report contents, contact information, addresses, VIN where linked to a person, carrier decision details, and consent evidence.

Controls:
- TLS in transit;
- encrypted storage;
- field-level encryption or tokenization for high-risk identifiers;
- keys separated from application data;
- managed KMS;
- no plaintext secrets in CI logs or source;
- masked display by default;
- clipboard/export controls considered for agent UI;
- bulk export disabled by default.

Privacy access exports require verified identity plus the scoped request credential. Plaintext exports MUST NOT be persisted. Stored export artifacts MUST be encrypted, directly inaccessible to anonymous/authenticated Data API roles, integrity checked before delivery, tenant/agency scoped, and audited on creation and every successful download. No-match and ambiguous discovery results MUST not expose candidate identifiers or counts.

## Provider credential security
- secrets stored only in managed secret storage;
- distinct sandbox/production credentials;
- no provider secret exposed to browser/mobile clients;
- egress requests originate server-side;
- credential rotation runbook;
- provider access revocation tested.

## Audit integrity
AuditEvent MUST cover:
- login/MFA changes;
- sensitive object reads;
- regulated provider requests;
- provider results and failures;
- exports;
- consent/notice actions;
- privacy requests;
- privacy-rights execution preparation, correction settlement, exemptions, restrictions, and disposition work;
- downstream privacy propagation preparation, adapter binding, attempts, failures, and completion;
- retention scheduling, policy resolution, blocked/held work, disposition attempts, and completion;
- legal-hold placement, scope, authority/evidence references, release, and post-release reevaluation;
- adverse-action determination authority, exact report/CRA provenance, ownership-policy snapshot, and handoff evidence;
- carrier submissions;
- role/config changes;
- secret/integration changes;
- retention/deletion actions.

Audit data MUST be append-only at the logical level and protected from ordinary application-user modification. Use hash chaining, WORM/immutable storage, or equivalent tamper-evidence where appropriate.

Compliance evidence export requires MFA and the intersection of `AUDIT_READ` and `EXPORT_DATA`; neither permission alone is sufficient. Tenant/agency scope is resolved from the stored QuoteCase. Export artifacts have no direct Data API grants, are immutable after creation, are capped at 10,000 evidence records, exclude high-risk payload fields, and verify their manifest hash before every audited download. Unauthorized and cross-tenant requests do not provide an existence oracle.

Adverse-action delivery tables deny direct anonymous/authenticated mutation. Checked MFA-backed `POLICY_ADMIN` RPCs prepare and settle delivery, with tenant scope resolved from the stored case rather than caller-supplied tenant data. Notice, owner, and adapter identity is immutable after preparation; attempts are append-only; and audit metadata uses opaque recipient and provider evidence references rather than destination addresses or notice bodies.

Notice/version tables deny direct anonymous/authenticated reads and writes. Checked private implementations and narrow public invoker wrappers require MFA-backed `POLICY_ADMIN`; tenant and agency are validated against active workforce context. Version allocation and SHA-256 hashing occur in PostgreSQL under an advisory lock. Lifecycle evidence is append-only, request hashes are server-derived, legal copy cannot be rewritten, and historical versions cannot be deleted.

## Application security baseline
- OWASP ASVS-informed controls;
- schema validation on every trust boundary;
- output encoding;
- parameterized DB access;
- CSRF protection;
- strict CSP;
- secure cookie attributes;
- rate limiting;
- brute-force/OTP abuse controls;
- SSRF protection for server-side integrations;
- no arbitrary callback URLs;
- dependency pinning and vulnerability scanning;
- secret scanning;
- SAST and dependency review in CI.

## Privacy-safe telemetry
Never log:
- full driver's license numbers;
- DOB;
- full addresses unless specifically required in a protected security log;
- raw MVR/claims report contents;
- consumer-report documents;
- provider secrets;
- magic links/OTPs;
- full access tokens.

Telemetry uses opaque IDs and categorized outcomes.

## Abuse prevention
The system MUST detect and alert on:
- repeated denied lookup attempts;
- one user accessing unusually many prospects;
- excessive provider orders;
- cross-agency access attempts;
- repeated exports;
- failed MFA spikes;
- unusual admin changes;
- provider credential errors suggestive of misuse.

Abuse detection is for security operations; it MUST NOT become a consumer insurance risk signal.

## Secure SDLC
Required before production:
- threat model reviewed;
- code review for security-sensitive changes;
- dependency and secret scanning;
- SAST;
- infrastructure configuration review;
- penetration test or equivalent independent assessment;
- privacy/PII logging test;
- backup/restore test;
- credential rotation test;
- provider outage/failure drill;
- incident response tabletop.

## Incident response
Severity model MUST cover confidentiality, integrity, availability, and unauthorized regulated-data access.

Runbook stages:
1. detect;
2. contain;
3. preserve evidence;
4. revoke/rotate compromised credentials;
5. identify affected subjects/data/providers/carriers;
6. legal/compliance assessment;
7. notification decisions;
8. eradicate and recover;
9. validate controls;
10. post-incident corrective actions.

## Backup and recovery
- encrypted backups;
- restore drills;
- backup access restricted;
- retention aligned with record policy;
- deletion strategy accounts for backups and legal obligations;
- `reliability-v1` requires a 5-minute maximum RPO and 4-hour maximum RTO for the PostgreSQL system of record, durable queues, and identity state; application/versioned configuration requires zero data-loss RPO and 1-hour RTO. These remain `UNVERIFIED` production blockers until the selected Vercel/Supabase plans and T902 restore drill prove them.

## Security launch blockers
- unresolved critical/high findings;
- no MFA for workforce;
- provider credentials accessible client-side;
- missing object-level authorization tests;
- PII present in ordinary application logs;
- arbitrary lookup path exists;
- audit events can be edited/deleted by normal app roles;
- production uses synthetic/test provider credentials or vice versa;
- incident response owner missing.
