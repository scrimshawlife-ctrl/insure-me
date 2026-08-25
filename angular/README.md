# Insure Me Angular Presentation Workspace

This workspace is the Angular 22.x presentation runtime introduced by `specs/002-angular-presentation-migration`.

It coexists with the current Next.js runtime during migration. It MUST consume canonical HTTP contracts and MUST NOT import server-only application, domain, persistence, provider, carrier, compliance, or Supabase modules from the repository root.

## Authority boundary
Angular owns presentation, navigation, client form state, transient UI state, and HTTP consumption. Server APIs remain authoritative for QuoteCase lifecycle, consent evidence, permissible purpose, provider execution, readiness, carrier decisions, privacy, adverse action, legal holds, tenant/role authority, and audit state.

## Commands
Run from this directory after dependencies are installed:

```bash
pnpm install
pnpm start
pnpm build
pnpm test
```

The initial workspace is intentionally shell-first. Feature implementation begins only against contracts frozen in `specs/002-angular-presentation-migration/t0-api-contract-addendum.md`.
