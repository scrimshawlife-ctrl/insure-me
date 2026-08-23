# Integration Specification

## Principle
Integrations are capability providers behind stable internal interfaces. No vendor becomes canonical domain language.

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
- agency/carrier eligibility;
- exact API/product access;
- California fields and restrictions;
- FCRA/CRA role by product;
- permissible-purpose codes;
- consumer notice/authorization requirements;
- raw payload storage rules;
- report retention;
- dispute workflow;
- pricing/minimums;
- sandbox availability;
- Allstate approval.

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

The platform MUST NOT infer chargeability or rating impact unless carrier-approved rules explicitly provide it.

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

The platform MUST NOT label a claim at-fault unless that fact is directly sourced or carrier-approved logic establishes it.

## Vehicle adapter
Normalized output MAY support:
- VIN decode;
- year/make/model/trim;
- body/engine/safety attributes;
- title/vehicle-history events where product permits;
- ownership/registration-derived attributes only when legally and contractually permitted.

## Prefill adapter
Prefill is treated as candidate data requiring confirmation where appropriate.

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

## Carrier integration: Allstate
Current state: `BLOCKED / UNVERIFIED`.

Before implementation, determine:
- whether a local Allstate agency may use an external consumer intake front end;
- whether Allstate supplies approved agency APIs, comparative rater integration, deep links, or import formats;
- whether Allstate mandates approved MVR/claims vendors;
- whether Allstate permits storage of prospect, report, and carrier-decision data in this platform;
- security assessment/vendor onboarding requirements;
- required agent authentication/SSO;
- whether quoting can be API-driven or must remain inside Allstate systems;
- allowed use of Allstate branding/trademarks;
- whether the local agency is captive and what outside-carrier functionality is permitted.

Until answered, `CarrierAdapter` MUST remain mocked/stubbed.

## Carrier handoff modes
Preferred order depends on carrier approval, not engineering preference:
1. API submission/response;
2. approved deep link with prefilled context;
3. secure structured export/import;
4. controlled manual handoff.

A browser automation or screen-scraping integration with a carrier portal is prohibited unless the carrier expressly authorizes it.

## Notification providers
Provider-agnostic interface:
- transactional email;
- transactional SMS;
- delivery/bounce status;
- template/version reference;
- suppression/opt-out handling.

Marketing campaigns are out of MVP scope.

## Integration testing
Every provider adapter MUST have:
- contract tests against recorded synthetic/sandbox fixtures;
- no-hit fixture;
- partial fixture;
- timeout fixture;
- auth failure fixture;
- malformed response fixture;
- duplicate idempotency fixture;
- California restriction fixture;
- prohibited-purpose fixture;
- redaction/logging test.

## Vendor substitution
Replacing Provider A with Provider B requires:
- field mapping comparison;
- legal/contract comparison;
- notice/authorization comparison;
- FCRA role comparison;
- retention comparison;
- data-use matrix update;
- acceptance rerun.

A provider swap is not a simple credential change.
