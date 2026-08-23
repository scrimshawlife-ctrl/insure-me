import { describe, expect, it } from 'vitest';
import {
  assertQuoteCaseTransition,
  canTransitionQuoteCase,
} from '../../src/domain/quote/lifecycle';

describe('QuoteCase lifecycle', () => {
  it('allows the canonical happy-path transitions', () => {
    expect(canTransitionQuoteCase('DRAFT', 'NOTICE_REQUIRED')).toBe(true);
    expect(canTransitionQuoteCase('NOTICE_REQUIRED', 'CONSUMER_INPUT')).toBe(true);
    expect(canTransitionQuoteCase('CONSUMER_INPUT', 'DATA_ENRICHMENT')).toBe(true);
    expect(canTransitionQuoteCase('DATA_ENRICHMENT', 'READY_FOR_CARRIER')).toBe(true);
    expect(canTransitionQuoteCase('READY_FOR_CARRIER', 'SUBMITTED_TO_CARRIER')).toBe(true);
    expect(canTransitionQuoteCase('SUBMITTED_TO_CARRIER', 'CARRIER_RESPONSE')).toBe(true);
    expect(canTransitionQuoteCase('CARRIER_RESPONSE', 'CLOSED')).toBe(true);
  });

  it('rejects invalid jumps', () => {
    expect(() => assertQuoteCaseTransition('DRAFT', 'SUBMITTED_TO_CARRIER')).toThrow(
      'QUOTE_CASE_TRANSITION_NOT_ALLOWED:DRAFT->SUBMITTED_TO_CARRIER',
    );
  });

  it('does not allow active processing from retention hold', () => {
    expect(canTransitionQuoteCase('RETENTION_HOLD', 'REVIEW_REQUIRED')).toBe(false);
  });
});
