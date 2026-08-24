# Integration Specification

## Principle
Integrations are capability providers behind stable internal interfaces. No vendor or carrier becomes canonical domain language.

The platform MUST be independently deployable before any production carrier is selected. Carrier onboarding is configuration plus adapter certification, not a redesign.

## Required MVP capability classes
1. Identity verification
2. Data prefill
3. Motor Vehicle Record (MVR)
4. Claims history / consumer report
5. Vehicle/VIN data
6. Carrier handoff
7. Transactional email/SMS

## Candidate insurance data providers

### LexisNexis Risk Solutions
Potential capabilities include:
- Auto Data Prefill;
- Motor Vehicle Records;
- C.L.U.E. Auto claims history;
- Vehicle History;
- Current Carrier or related insurance-history products.

Status: `CANDIDATE / UNCONTRACTED`.

Required diligence:
- agency eligibility;
- carrier compatibility where relevant;
- exact API/product access;
- California fields and restrictions;
- FCRA/CRA role by product;
- permissible-purpose codes;
- consumer notice/authorization requirements;
- raw payload storage rules;
- report retention;
- dispute workflow;
- pricing/minimums;
- sandbox availability.

### Verisk
Potential capabilities include:
- motor vehicle reports;
- A-PLUS claims/loss history;
- VIN/vehicle data;
- vehicle registration-related products subject to state restrictions.

Status: `CANDIDATE / UNCONTRACTED`.

Required diligence is the same as above. California-specific product restrictions MUST be encoded per capability, not assumed from national availability.

## Provider adapter capability schema
Each configured capability MUST declare:
- provider ID;
- product ID/version;
- supported jurisdictions;
- supported insurance product lines;
- purpose codes;
- required subject fields;
- required notice/authorization IDs;
- whether it is a consumer report/CRA product;
- whether raw payload storage is allowed;
- freshness/refresh constraints;
- provider-side retention constraints;
- rate limits;
- timeout/retry policy;
- no-hit/partial semantics;
- dispute/contact metadata;
- contract effective/expiration dates.

## MVR adapter
Normalized minimum output SHOULD support where provider supplies it:
- report status;
- driver identity match state;
- license state/status/class;
- first-issued/years-licensed signal;
- violations with type/date/jurisdiction;
- suspensions/revocations;
- accidents appearing in the MVR product;
- provider warnings/no-hit/partial status.

The platform MUST NOT infer chargeability or rating impact unless approved rules for the configured carrier explicitly provide it.

## Claims adapter
Normalized output SHOULD support:
- report status;
- claim date;
- loss type;
- subject driver/vehicle when supplied;
- claim/reference identifiers;
- loss/payment attributes when contractually allowed;
- disposition/status;
- provider warnings.

The platform MUST NOT label a claim at-fault unless directly sourced or approved carrier logic establishes it.

## Vehicle adapter
Normalized output MAY support:
- VIN decode;
- year/make/model/trim;
- body/engine/safety attributes;
- title/vehicle-history events where product permits;
- ownership/registration-derived attributes only when legally and contractually permitted.

## Prefill adapter
Prefill is candidate data requiring confirmation where appropriate.

Each returned candidate MUST preserve:
- source;
- match confidence/status if supplied;
- subject relation;
- field-level provenance;
- consumer confirmation/edit state.

Prefill MUST NOT create a hidden household graph used for unrelated profiling.

## Identity provider
Identity verification is for transaction security and provider prerequisites. It is not an underwriting score.

Normalized output SHOULD be limited to:
- verified/not verified/review;
- reason category;
- assurance level;
- provider reference;
- timestamp.

Do not persist unnecessary identity-document images unless explicitly required and approved.

## Carrier abstraction
Carrier integration is represented only through a stable `CarrierAdapter` contract.

No carrier name, proprietary field, portal workflow, rating rule, authentication scheme, or brand asset may leak into the core domain model.

Each carrier configuration MUST declare:
- carrier ID and product/program ID;
- jurisdictions and product lines;
- submission mode;
- required and optional input fields;
- field mapping from canonical schema;
- rating-input allowlist;
- authentication method;
- endpoint/deep-link/export metadata;
- response schema and reason-code mapping;
- whether carrier responses may be retained and for how long;
- notice/adverse-action ownership;
- agent authorization requirements;
- branding permissions;
- certification/sandbox status;
- kill-switch state.

## Carrier handoff modes
The adapter MUST support one or more of these modes without changing the canonical QuoteCase model:
1. API submission and response;
2. approved deep link with prefilled context;
3. comparative-rater or agency-management-system bridge;
4. secure structured export/import;
5. controlled manual handoff.

Browser automation or screen scraping of a carrier portal is prohibited unless that carrier expressly authorizes it.

## Multi-carrier readiness
The MVP MAY activate only one real carrier adapter, but the architecture MUST support multiple configured carriers.

A quote case MAY contain zero, one, or multiple carrier eligibility/handoff targets. Multi-carrier comparative quoting itself is not required for MVP, but the model MUST NOT preclude it.

Core services MUST NOT branch on carrier names. They may branch only on declared capabilities, policy configuration, jurisdiction, and product line.

## Notification providers
Provider-agnostic interface:
- transactional email;
- transactional SMS;
- delivery/bounce status;
- template/version reference;
- suppression/opt-out handling.

Adverse-action delivery uses a provider-neutral `NoticeDeliveryAdapter`. Its descriptor includes adapter ID/version, delivery-policy version, and certification state. Requests contain only opaque case/delivery/recipient references plus the exact NoticeDefinition version/hash, approved channel, and idempotency key. Provider acceptance and confirmed delivery are distinct outcomes. Synthetic adapters are deterministic and prohibited outside the synthetic stage; live adapters require deployment-specific certification and evidence semantics.

Marketing campaigns are out of MVP scope.

## Integration testing
Every provider and carrier adapter MUST have:
- contract tests against synthetic/sandbox fixtures;
- no-hit or unavailable fixture where applicable;
- partial fixture;
- timeout fixture;
- auth failure fixture;
- malformed response fixture;
- duplicate/idempotency fixture;
- California restriction fixture where relevant;
- prohibited-purpose fixture for regulated data providers;
- redaction/logging test;
- disable/kill-switch test.

## Vendor or carrier substitution
Replacing Provider A with Provider B, or Carrier A with Carrier B, requires:
- field mapping comparison;
- legal/contract comparison;
- notice/authorization comparison;
- FCRA role comparison where applicable;
- retention comparison;
- data-use matrix update;
- adapter contract tests;
- acceptance rerun.

A provider or carrier swap is not a credential change, but it MUST NOT require a core-domain fork.
