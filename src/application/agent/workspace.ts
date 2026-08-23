import type { SupabaseClient } from '@supabase/supabase-js';

import type { Database } from '@/src/infrastructure/supabase/database.types';

export interface AgentQueueItem {
  quoteCaseId: string;
  state: Database['public']['Enums']['quote_case_state'];
  assignedAgentId: string | null;
  jurisdiction: string;
  productLine: string;
  sourceChannel: string;
  createdAt: string;
  updatedAt: string;
  blockingIssueCount: number;
  warningIssueCount: number;
}

export interface AgentReadinessIssue {
  readinessIssueId: string;
  issueType: string;
  severity: string;
  blocking: boolean;
  reasonCode: string;
  subjectRef: string | null;
  createdAt: string;
}

export interface AgentCaseSummary {
  quoteCaseId: string;
  state: Database['public']['Enums']['quote_case_state'];
  assignedAgentId: string | null;
  jurisdiction: string;
  productLine: string;
  sourceChannel: string;
  selectedCarrierProgramId: string | null;
  createdAt: string;
  updatedAt: string;
  readinessIssues: AgentReadinessIssue[];
}

export async function listAgentQueue(
  client: SupabaseClient<Database>,
): Promise<AgentQueueItem[]> {
  const { data: cases, error: caseError } = await client
    .from('quote_cases')
    .select('quote_case_id,state,assigned_agent_id,jurisdiction,product_line,source_channel,created_at,updated_at')
    .order('updated_at', { ascending: false })
    .limit(100);

  if (caseError) throw new Error(`AGENT_QUEUE_CASES_FAILED:${caseError.message}`);
  if (!cases || cases.length === 0) return [];

  const ids = cases.map((item) => item.quote_case_id);
  const { data: issues, error: issueError } = await client
    .from('readiness_issues')
    .select('quote_case_id,severity,blocking')
    .in('quote_case_id', ids)
    .eq('resolution_state', 'OPEN');

  if (issueError) throw new Error(`AGENT_QUEUE_READINESS_FAILED:${issueError.message}`);

  const counts = new Map<string, { blocking: number; warning: number }>();
  for (const issue of issues ?? []) {
    const current = counts.get(issue.quote_case_id) ?? { blocking: 0, warning: 0 };
    if (issue.blocking) current.blocking += 1;
    else if (issue.severity === 'WARNING') current.warning += 1;
    counts.set(issue.quote_case_id, current);
  }

  return cases.map((item) => {
    const issueCounts = counts.get(item.quote_case_id) ?? { blocking: 0, warning: 0 };
    return {
      quoteCaseId: item.quote_case_id,
      state: item.state,
      assignedAgentId: item.assigned_agent_id,
      jurisdiction: item.jurisdiction,
      productLine: item.product_line,
      sourceChannel: item.source_channel,
      createdAt: item.created_at,
      updatedAt: item.updated_at,
      blockingIssueCount: issueCounts.blocking,
      warningIssueCount: issueCounts.warning,
    };
  });
}

export async function getAgentCaseSummary(
  client: SupabaseClient<Database>,
  quoteCaseId: string,
): Promise<AgentCaseSummary | null> {
  const { data: quoteCase, error: caseError } = await client
    .from('quote_cases')
    .select('quote_case_id,state,assigned_agent_id,jurisdiction,product_line,source_channel,selected_carrier_program_id,created_at,updated_at')
    .eq('quote_case_id', quoteCaseId)
    .maybeSingle();

  if (caseError) throw new Error(`AGENT_CASE_FAILED:${caseError.message}`);
  if (!quoteCase) return null;

  const { data: issues, error: issueError } = await client
    .from('readiness_issues')
    .select('readiness_issue_id,issue_type,severity,blocking,reason_code,subject_ref,created_at')
    .eq('quote_case_id', quoteCaseId)
    .eq('resolution_state', 'OPEN')
    .order('blocking', { ascending: false })
    .order('created_at', { ascending: true });

  if (issueError) throw new Error(`AGENT_CASE_READINESS_FAILED:${issueError.message}`);

  return {
    quoteCaseId: quoteCase.quote_case_id,
    state: quoteCase.state,
    assignedAgentId: quoteCase.assigned_agent_id,
    jurisdiction: quoteCase.jurisdiction,
    productLine: quoteCase.product_line,
    sourceChannel: quoteCase.source_channel,
    selectedCarrierProgramId: quoteCase.selected_carrier_program_id,
    createdAt: quoteCase.created_at,
    updatedAt: quoteCase.updated_at,
    readinessIssues: (issues ?? []).map((issue) => ({
      readinessIssueId: issue.readiness_issue_id,
      issueType: issue.issue_type,
      severity: issue.severity,
      blocking: issue.blocking,
      reasonCode: issue.reason_code,
      subjectRef: issue.subject_ref,
      createdAt: issue.created_at,
    })),
  };
}
