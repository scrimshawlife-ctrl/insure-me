import Link from 'next/link';
import { notFound } from 'next/navigation';

import styles from '../../agent.module.css';
import { getAgentCaseSummary } from '@/src/application/agent/workspace';
import { assertWorkforcePermission } from '@/src/domain/auth/workforce';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

function displayTime(value: string): string {
  return new Intl.DateTimeFormat('en-US', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

export default async function AgentQuoteCasePage({ params }: { params: Promise<{ id: string }> }) {
  const { id: quoteCaseId } = await params;
  const supabase = await createSupabaseServerClient();

  try {
    const context = await requireWorkforceContext(supabase);
    assertWorkforcePermission(context, 'CASE_READ');
    const summary = await getAgentCaseSummary(supabase, quoteCaseId);
    if (!summary) notFound();

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
              {summary.readinessIssues.length === 0 ? (
                <p className={styles.clear}>No open readiness issues.</p>
              ) : (
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
        </section>
      </main>
    );
  } catch {
    notFound();
  }
}
