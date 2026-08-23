export const QUOTE_CASE_STATES = [
  'DRAFT',
  'NOTICE_REQUIRED',
  'CONSUMER_INPUT',
  'DATA_ENRICHMENT',
  'REVIEW_REQUIRED',
  'READY_FOR_CARRIER',
  'SUBMITTED_TO_CARRIER',
  'CARRIER_RESPONSE',
  'FOLLOW_UP',
  'CLOSED',
  'ABANDONED',
  'RETENTION_HOLD',
] as const;

export type QuoteCaseState = (typeof QUOTE_CASE_STATES)[number];

const ALLOWED_TRANSITIONS: Readonly<Record<QuoteCaseState, readonly QuoteCaseState[]>> = {
  DRAFT: ['NOTICE_REQUIRED', 'ABANDONED'],
  NOTICE_REQUIRED: ['CONSUMER_INPUT', 'ABANDONED'],
  CONSUMER_INPUT: ['DATA_ENRICHMENT', 'REVIEW_REQUIRED', 'ABANDONED'],
  DATA_ENRICHMENT: ['REVIEW_REQUIRED', 'READY_FOR_CARRIER', 'ABANDONED'],
  REVIEW_REQUIRED: ['CONSUMER_INPUT', 'DATA_ENRICHMENT', 'READY_FOR_CARRIER', 'ABANDONED'],
  READY_FOR_CARRIER: ['REVIEW_REQUIRED', 'SUBMITTED_TO_CARRIER', 'ABANDONED'],
  SUBMITTED_TO_CARRIER: ['CARRIER_RESPONSE', 'FOLLOW_UP'],
  CARRIER_RESPONSE: ['FOLLOW_UP', 'CLOSED'],
  FOLLOW_UP: ['REVIEW_REQUIRED', 'READY_FOR_CARRIER', 'CLOSED', 'ABANDONED'],
  CLOSED: ['RETENTION_HOLD'],
  ABANDONED: ['RETENTION_HOLD'],
  RETENTION_HOLD: [],
};

export function canTransitionQuoteCase(
  from: QuoteCaseState,
  to: QuoteCaseState,
): boolean {
  return ALLOWED_TRANSITIONS[from].includes(to);
}

export function assertQuoteCaseTransition(
  from: QuoteCaseState,
  to: QuoteCaseState,
): void {
  if (!canTransitionQuoteCase(from, to)) {
    throw new Error(`QUOTE_CASE_TRANSITION_NOT_ALLOWED:${from}->${to}`);
  }
}
