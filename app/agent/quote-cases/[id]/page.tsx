import Link from 'next/link';
import { notFound } from 'next/navigation';

import styles from '../../agent.module.css';
import { ProviderRefreshButton } from './provider-refresh-button';
import { getAgentProviderContext } from '@/src/application/agent/provider-context';
import { getAgentCaseIntake, getAgentCaseSummary } from '@/src/application/agent/workspace';
import { assertWorkforcePermission } from '@/src/domain/auth/workforce';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

function displayTime(value: string): string {
  return new Intl.DateTimeFormat('en-US', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value));
}

function jsonSummary(value: unknown): string {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return String(value ?? 'Not specified');
  const entries = Object.entries(value as Record<string, unknown>);
  if (entries.length === 0) return 'Not specified';
  return entries.map(([key, item]) => `${key}: ${String(item)}`).join(' · ');
}

async function loadCase(quoteCaseId: string) {
  const supabase = await createSupabaseServerClient();
  try {
    const context = await requireWorkforceContext(supabase);
    assertWorkforcePermission(context, 'CASE_READ');
    const [summary, intake, providers] = await Promise.all([
      getAgentCaseSummary(supabase, quoteCaseId),
      getAgentCaseIntake(supabase, quoteCaseId),
      getAgentProviderContext(supabase, quoteCaseId),
    ]);
    if (!summary) return null;
    return { summary, intake, providers };
  } catch {
    return null;
  }
}

export default async function AgentQuoteCasePage({ params }: { params: Promise<{ id: string }> }) {
  const { id: quoteCaseId } = await params;
  const loaded = await loadCase(quoteCaseId);
  if (!loaded) notFound();

  const { summary, intake, providers } = loaded;
  const blockingCount = summary.readinessIssues.filter((issue) => issue.blocking).length;
  const warningCount = summary.readinessIssues.filter((issue) => !issue.blocking && issue.severity === 'WARNING').length;

  return (
    <main className={styles.shell}>
      <header className={styles.header}>
        <Link className={styles.brand} href="/agent">Insure Me · Agent</Link>
        <span className={styles.context}>Quote {summary.quoteCaseId.slice(0, 8)}</span>
      </header>
      <section className={styles.main}>
        <p className={styles.eyebrow}>Quote detail</p>
        <h1 className={styles.title}>Readiness before handoff</h1>
        <p className={styles.subhead}>This view shows workflow completeness and operational blockers. It does not express a risk, eligibility, or premium score.</p>

        <div className={styles.summary} aria-label="Case readiness summary">
          <div className={styles.metric}><strong>{summary.state.replaceAll('_', ' ')}</strong><span>Current state</span></div>
          <div className={styles.metric}><strong>{blockingCount}</strong><span>Open blockers</span></div>
          <div className={styles.metric}><strong>{warningCount}</strong><span>Open warnings</span></div>
        </div>

        <div className={styles.grid}>
          <section className={styles.card} aria-labelledby="readiness-heading">
            <h2 id="readiness-heading">Readiness issues</h2>
            {summary.readinessIssues.length === 0 ? <p className={styles.clear}>No open readiness issues.</p> : (
              <ul className={styles.issueList}>
                {summary.readinessIssues.map((issue) => (
                  <li className={styles.issue} data-blocking={issue.blocking} key={issue.readinessIssueId}>
                    <strong>{issue.blocking ? 'Blocking' : issue.severity}</strong>
                    <p>{issue.issueType.replaceAll('_', ' ')}</p>
                    <span className={styles.issueCode}>{issue.reasonCode}</span>
                    {issue.subjectRef && <p>Subject: {issue.subjectRef}</p>}
                  </li>
                ))}
              </ul>
            )}
          </section>

          <aside className={styles.card}>
            <h3>Case context</h3>
            <dl className={styles.metaList}>
              <div><dt>Quote reference</dt><dd>{summary.quoteCaseId.slice(0, 8)}</dd></div>
              <div><dt>Jurisdiction</dt><dd>{summary.jurisdiction}</dd></div>
              <div><dt>Product</dt><dd>{summary.productLine.replaceAll('_', ' ')}</dd></div>
              <div><dt>Source</dt><dd>{summary.sourceChannel}</dd></div>
              <div><dt>Assignment</dt><dd>{summary.assignedAgentId ? summary.assignedAgentId.slice(0, 8) : 'Unassigned'}</dd></div>
              <div><dt>Carrier program</dt><dd>{summary.selectedCarrierProgramId ? summary.selectedCarrierProgramId.slice(0, 8) : 'Not selected'}</dd></div>
              <div><dt>Created</dt><dd>{displayTime(summary.createdAt)}</dd></div>
              <div><dt>Updated</dt><dd>{displayTime(summary.updatedAt)}</dd></div>
            </dl>
          </aside>
        </div>

        <div className={styles.grid}>
          <section className={styles.card} aria-labelledby="drivers-heading">
            <h2 id="drivers-heading">Drivers</h2>
            {intake.drivers.length === 0 ? <p>No driver records are available.</p> : (
              <ul className={styles.issueList}>
                {intake.drivers.map((driver) => (
                  <li className={styles.issue} key={driver.driverId}>
                    <strong>{driver.firstName} {driver.lastName}</strong>
                    <p>{driver.relationshipRole.replaceAll('_', ' ')} · born {driver.dateOfBirth}</p>
                    <p>License: {driver.licenseJurisdiction}{driver.licenseLast4 ? ` · ending ${driver.licenseLast4}` : ' · not stored'}{driver.licenseStatus ? ` · ${driver.licenseStatus}` : ''}</p>
                    <span className={styles.issueCode}>{driver.sourceType} · {driver.confirmationState}</span>
                  </li>
                ))}
              </ul>
            )}
          </section>

          <section className={styles.card} aria-labelledby="vehicles-heading">
            <h2 id="vehicles-heading">Vehicles</h2>
            {intake.vehicles.length === 0 ? <p>No vehicle records are available.</p> : (
              <ul className={styles.issueList}>
                {intake.vehicles.map((vehicle) => (
                  <li className={styles.issue} key={vehicle.vehicleId}>
                    <strong>{vehicle.modelYear} {vehicle.make} {vehicle.model}</strong>
                    <p>{vehicle.trim ?? 'Trim not specified'} · {vehicle.usage.replaceAll('_', ' ')}</p>
                    <p>VIN: {vehicle.vinLast4 ? `ending ${vehicle.vinLast4}` : 'not stored'}{vehicle.annualMileage !== null ? ` · ${vehicle.annualMileage.toLocaleString()} mi/year` : ''}</p>
                    <span className={styles.issueCode}>{vehicle.sourceType} · {vehicle.confirmationState}</span>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>

        <section className={styles.card} aria-labelledby="coverage-heading">
          <h2 id="coverage-heading">Coverage request</h2>
          {intake.coverageRequest ? (
            <dl className={styles.metaList}>
              <div><dt>Requested limits</dt><dd>{jsonSummary(intake.coverageRequest.requestedLimits)}</dd></div>
              <div><dt>Preferences</dt><dd>{jsonSummary(intake.coverageRequest.preferences)}</dd></div>
              <div><dt>Notes</dt><dd>{intake.coverageRequest.notes ?? 'None'}</dd></div>
              <div><dt>Updated</dt><dd>{displayTime(intake.coverageRequest.updatedAt)}</dd></div>
            </dl>
          ) : <p>No coverage request is available.</p>}
        </section>

        <section className={styles.card} aria-labelledby="provider-status-heading">
          <h2 id="provider-status-heading">External report status</h2>
          <p className={styles.subhead}>Provider status is operational metadata only. Raw provider payloads are not shown here.</p>
          {providers.reports.length === 0 ? <p>No active provider bindings apply to this case.</p> : (
            <ul className={styles.issueList}>
              {providers.reports.map((report) => (
                <li className={styles.issue} key={report.providerBindingId}>
                  <div className={styles.rowBetween}>
                    <div>
                      <strong>{report.capability}</strong>
                      <p>{report.reportStatus ?? report.requestStatus ?? 'NOT_REQUESTED'}{report.requiredForReadiness ? ' · required for readiness' : ''}</p>
                      <span className={styles.issueCode}>{report.adapterId}@{report.adapterVersion}</span>
                    </div>
                    <ProviderRefreshButton
                      capability={report.capability}
                      enabled={report.canRefresh}
                      quoteCaseId={quoteCaseId}
                      subjectIds={report.subjectIds}
                    />
                  </div>
                  {report.retrievedAt && <p>Retrieved {displayTime(report.retrievedAt)}{report.freshUntil ? ` · fresh until ${displayTime(report.freshUntil)}` : ''}</p>}
                  {report.warnings.length > 0 && <p className={styles.warning}>{report.warnings.join(' · ')}</p>}
                  {!providers.canRefreshProviders && <p className={styles.context}>REPORT_RETRIEVE permission is required to refresh.</p>}
                  {providers.canRefreshProviders && report.subjectIds.length === 0 && <p className={styles.context}>No prior subject context is available for a safe refresh.</p>}
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className={styles.card} aria-labelledby="observations-heading">
          <h2 id="observations-heading">Underwriting observations</h2>
          <p className={styles.subhead}>Only observations admitted by the active data-use policy for agent display are projected.</p>
          {providers.observations.length === 0 ? <p>No policy-displayable observations are available.</p> : (
            <ul className={styles.issueList}>
              {providers.observations.map((observation) => (
                <li className={styles.issue} key={observation.observationId}>
                  <strong>{observation.observationType.replaceAll('_', ' ')}</strong>
                  <p>{jsonSummary(observation.normalizedValue)}</p>
                  <span className={styles.issueCode}>{observation.freshnessState} · {observation.conflictState} · {observation.dataUseClassification}</span>
                  <details className={styles.provenance}>
                    <summary>Provenance ({observation.provenance.length})</summary>
                    {observation.provenance.length === 0 ? <p>No provenance entries are linked.</p> : (
                      <ul className={styles.issueList}>
                        {observation.provenance.map((entry) => (
                          <li className={styles.provenanceEntry} key={entry.provenanceEntryId}>
                            <strong>{entry.factKey}</strong>
                            <p>{entry.sourceType} · {entry.sourceId}</p>
                            <span className={styles.issueCode}>{entry.transformationVersion}{entry.confidenceState ? ` · ${entry.confidenceState}` : ''}{entry.confirmationState ? ` · ${entry.confirmationState}` : ''}</span>
                          </li>
                        ))}
                      </ul>
                    )}
                  </details>
                </li>
              ))}
            </ul>
          )}
        </section>
      </section>
    </main>
  );
}
