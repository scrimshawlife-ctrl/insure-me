import Link from 'next/link';

import styles from './agent.module.css';
import { listAgentQueue } from '@/src/application/agent/workspace';
import { assertWorkforcePermission } from '@/src/domain/auth/workforce';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

function relativeAge(iso: string): string {
  const elapsedMinutes = Math.max(0, Math.floor((Date.now() - new Date(iso).getTime()) / 60000));
  if (elapsedMinutes < 60) return `${elapsedMinutes}m`;
  const hours = Math.floor(elapsedMinutes / 60);
  if (hours < 48) return `${hours}h`;
  return `${Math.floor(hours / 24)}d`;
}

async function loadQueue() {
  const supabase = await createSupabaseServerClient();
  try {
    const context = await requireWorkforceContext(supabase);
    assertWorkforcePermission(context, 'CASE_READ');
    return { authorized: true as const, context, queue: await listAgentQueue(supabase) };
  } catch {
    return { authorized: false as const };
  }
}

export default async function AgentQueuePage() {
  const result = await loadQueue();

  if (!result.authorized) {
    return (
      <main className={styles.shell}>
        <section className={styles.access}>
          <p className={styles.eyebrow}>Workforce access</p>
          <h1>Agent workspace unavailable</h1>
          <p>Sign in with an authorized workforce account, complete MFA, and select an active tenant with case-read permission.</p>
        </section>
      </main>
    );
  }

  const { context, queue } = result;
  const blockingCases = queue.filter((item) => item.blockingIssueCount > 0).length;
  const unassigned = queue.filter((item) => !item.assignedAgentId).length;

  return (
    <main className={styles.shell}>
      <header className={styles.header}>
        <span className={styles.brand}>Insure Me · Agent</span>
        <span className={styles.context}>Active tenant {context.tenantId.slice(0, 8)}</span>
      </header>
      <section className={styles.main}>
        <p className={styles.eyebrow}>Quote operations</p>
        <h1 className={styles.title}>Agent workspace</h1>
        <p className={styles.subhead}>Cases are organized around completeness and blocking issues. This workspace does not calculate or display a consumer risk score.</p>

        <div className={styles.summary} aria-label="Queue summary">
          <div className={styles.metric}><strong>{queue.length}</strong><span>Visible cases</span></div>
          <div className={styles.metric}><strong>{blockingCases}</strong><span>Cases with blockers</span></div>
          <div className={styles.metric}><strong>{unassigned}</strong><span>Unassigned cases</span></div>
        </div>

        <div className={styles.tableWrap}>
          {queue.length === 0 ? (
            <div className={styles.empty}>No quote cases are visible in the active tenant.</div>
          ) : (
            <table className={styles.table}>
              <thead><tr><th>Quote</th><th>State</th><th>Assignment</th><th>Readiness</th><th>Source</th><th>Age</th><th>Updated</th></tr></thead>
              <tbody>
                {queue.map((item) => (
                  <tr key={item.quoteCaseId}>
                    <td><Link className={styles.caseLink} href={`/agent/quote-cases/${item.quoteCaseId}`}>{item.quoteCaseId.slice(0, 8)}</Link></td>
                    <td><span className={styles.state}>{item.state.replaceAll('_', ' ')}</span></td>
                    <td>{item.assignedAgentId ? `Assigned ${item.assignedAgentId.slice(0, 8)}` : 'Unassigned'}</td>
                    <td>{item.blockingIssueCount > 0 ? <span className={styles.blocking}>{item.blockingIssueCount} blocking</span> : item.warningIssueCount > 0 ? <span className={styles.warning}>{item.warningIssueCount} warning</span> : <span className={styles.clear}>No open blockers</span>}</td>
                    <td>{item.sourceChannel}</td><td>{relativeAge(item.createdAt)}</td><td>{relativeAge(item.updatedAt)} ago</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </section>
    </main>
  );
}
