# T0 Contract Inventory and Freeze

## Status
Canonical migration evidence for `specs/002-angular-presentation-migration`.

## Objective
Freeze the existing Insure Me browser-to-application contracts before Angular implementation begins. The Angular migration MUST preserve backend/domain/compliance authority and MUST NOT infer new canonical semantics from current Next.js UI structure.

## Current runtime baseline
The current web runtime is Next.js 16.3.2 + React 19.2.8 on Node 22 with Supabase SSR/session support, Zod validation, Vitest, and Playwright. Existing security verification includes lint, typecheck, tests, secret scanning, SAST, dependency audit, operational drills, privacy rehearsal, and adverse-action rehearsal.

## Preserve versus replace

| Surface | Current implementation | Angular disposition | Authority |
|---|---|---|---|
| Canonical domain/application services | `src/application/**`, `src/domain/**` | PRESERVE | Server/domain |
| Provider orchestration and normalization | `src/application/providers/**` | PRESERVE | Server/domain |
| Carrier orchestration | `src/application/carriers/**` | PRESERVE | Server/domain |
| Consent/notice ledger | `src/application/notice/**` | PRESERVE | Server/domain |
| Compliance/adverse action | `src/application/compliance/**` | PRESERVE | Server/domain |
| Privacy rights/legal holds/retention | `src/application/privacy/**` | PRESERVE | Server/domain |
| Policy inspection | `src/application/policy/**` | PRESERVE | Server/domain |
| Supabase persistence/database types | `src/infrastructure/supabase/**` | PRESERVE behind API boundary | Server/infrastructure |
| Browser session refresh | Next.js `proxy.ts` + Supabase SSR proxy | REPLACE with Angular-compatible auth/session integration while preserving server validation | Auth boundary |
| CSRF/origin mutation defense | `src/infrastructure/security/csrf` invoked by `proxy.ts` | PRESERVE behavior; relocate enforcement to framework-neutral server/gateway boundary where required | Security boundary |
| Next.js App Router pages/layouts | `app/**/page.tsx`, `layout.tsx` | REPLACE | Presentation |
| React client components/forms | `*.tsx` under `app/` | REPLACE with Angular standalone components/forms | Presentation |
| CSS visual tokens/styles | `app/globals.css`, CSS modules | REUSE/PORT selectively | Presentation |
| `/api/v1/**` route semantics | Next.js route handlers | FREEZE externally visible contract; implementation MAY move behind framework-neutral HTTP service | Server/API |
| `/api/internal/**` | Internal operational routes | PRESERVE semantics; keep inaccessible to public browser clients | Server/API |
| `/api/health/**` | Health endpoint | PRESERVE semantics | Operations |
| `/auth/confirm` | Next.js auth confirmation route | PRESERVE user-visible behavior; implementation MAY change | Auth boundary |
| Synthetic fixtures/tests | existing deterministic test corpus | PRESERVE and extend for Angular parity | Verification |

## Browser route inventory

### Public/start surfaces
- `/`
- `/quote`
- `/resume`
- `/auth/confirm`

### Consumer quote workflow
- `/quote/[id]`
- `/quote/[id]/notices`
- `/quote/[id]/drivers`
- `/quote/[id]/vehicles`
- `/quote/[id]/coverage`
- `/quote/[id]/review`

The current consumer implementation contains dedicated React forms/components for identity, notices, drivers, vehicles, coverage, review submission, and save/resume. Angular MUST preserve workflow meaning and state transitions, but MAY reorganize component boundaries.

### Agent workspace
- `/agent`
- `/agent/quote-cases/[id]`

The current agent case surface includes carrier-program selection, provider refresh, case actions, and a consolidated case detail view. Angular MUST preserve server authorization and case-action semantics.

## API contract classes

The existing `/api/v1` tree contains canonical browser/API routes grouped by domain. The migration MUST treat path, method, authorization behavior, idempotency semantics, response/error classes, and side effects as frozen until each route is explicitly classified.

Observed route families include:
- `agent/quote-cases/**`
- `agent/carrier-programs`
- `agent/adverse-actions/**`
- `agent/legal-holds/**`
- `admin/notice-definitions/**`
- `admin/data-use-policies`
- `admin/retention-policies`
- `admin/compliance-evidence-exports/**`

These are not presentation code. Angular MUST call them through a typed client/facade and MUST NOT import server application modules directly.

## Auth/session boundary

Current request middleware performs two functions before normal request handling:
1. rejects cross-site mutation attempts using origin/fetch-site checks;
2. refreshes/updates the Supabase session.

Angular migration requirements:
- authenticated browser state MUST remain subordinate to server-side session validation;
- no privileged role/tenant decision may depend only on Angular route guards;
- route guards are UX controls only;
- mutation-origin/CSRF protection MUST continue to be enforced on the server/gateway boundary;
- secure cookie/session behavior MUST remain compatible with the selected Angular hosting topology;
- `/auth/confirm` behavior MUST be parity-tested before cutover.

## State authority freeze

Angular Signals MAY hold:
- current workflow step;
- loading/error state;
- editable form drafts;
- view filters/selections;
- transient UI state.

Angular Signals MUST NOT become authoritative for:
- QuoteCase lifecycle state;
- consent/authorization evidence;
- provider-request authorization;
- readiness decisions;
- carrier decisions;
- adverse-action state;
- privacy-request state;
- legal holds;
- tenant or role authority.

Those values MUST be read from and mutated through canonical server APIs.

## Form contract freeze

The current React forms are implementation evidence, not canonical schemas. Angular form models MUST be derived from canonical domain/API schemas and specification requirements.

Required parity domains:
- quote initiation;
- consumer identity;
- notices/authorizations;
- drivers;
- vehicles;
- requested coverage;
- review/submit;
- save/resume.

Validation rules that are legally, contractually, or domain significant MUST remain server-enforced even when duplicated for client UX.

## Security contract freeze

The migration MUST preserve or improve:
- same-origin mutation protection;
- secure session handling;
- tenant isolation;
- MFA/workforce authorization behavior;
- no raw PII in telemetry;
- no provider/carrier credentials in browser bundles;
- no production secrets in source control;
- fail-closed regulated lookup prerequisites;
- existing security baseline commands and evidence expectations.

## Test contract freeze

The following verification surfaces remain canonical during migration:
- lint/typecheck;
- unit/contract tests;
- Playwright E2E;
- canonical synthetic scenario execution;
- provider outage drill;
- provider credential rotation drill;
- incident-response tabletop;
- privacy-rights rehearsal;
- adverse-action rehearsal;
- security baseline.

Angular implementation MAY introduce framework-specific tests, but MUST NOT remove these evidence categories before equivalent or stronger replacements are accepted.

## Migration classification

### REUSE UNCHANGED
- domain/application logic under `src/` that has no Next.js dependency;
- provider/carrier abstractions;
- compliance/privacy policy logic;
- persistence contracts;
- synthetic data fixtures;
- contract and operational test scenarios.

### WRAP / EXPOSE THROUGH HTTP
- any server application function currently invoked directly by a Next.js server component or route handler;
- Supabase server-side session/tenant resolution;
- internal service composition needed by Angular clients.

### REIMPLEMENT
- App Router pages/layouts;
- React form components;
- React-local state;
- Next.js navigation primitives;
- Next.js-specific session refresh middleware.

### RETIRE ONLY AFTER PARITY
- Next.js page tree;
- React dependencies;
- Next.js build/start scripts;
- Next.js-only configuration and middleware.

## T0 exit criteria
T0 is complete when:
1. the current page and API surface is inventoried;
2. server authority boundaries are frozen;
3. auth/session and CSRF behavior are explicitly preserved;
4. reuse/wrap/reimplement/retire classifications are recorded;
5. Angular implementation can begin without changing canonical insurance semantics;
6. no Next.js runtime surface is removed yet.

## T1 handoff
The next implementation slice MUST create the Angular workspace alongside the current runtime, not in place of it. It MUST establish:
- Angular 22.x standalone bootstrap;
- Angular Router;
- `HttpClient` with functional interceptors;
- typed API boundary;
- environment configuration without secrets;
- route-shell placeholders for public, consumer, agent, admin, and compliance surfaces;
- CI commands that do not disrupt existing Next.js verification.
