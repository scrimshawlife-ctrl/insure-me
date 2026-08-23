import { describe, expect, it } from 'vitest';

import {
  assertNoticeRequirement,
  consentActionSatisfiesNotice,
  isConsentActionValid,
  isQuoteBlockingNotice,
} from '@/src/domain/notice/consent';

describe('notice and consent semantics', () => {
  it('does not treat disclosure acknowledgment as report authorization', () => {
    expect(isConsentActionValid('REPORT_AUTHORIZATION', 'ACKNOWLEDGE')).toBe(false);
    expect(consentActionSatisfiesNotice('REPORT_AUTHORIZATION', 'ACKNOWLEDGE')).toBe(false);
    expect(consentActionSatisfiesNotice('REPORT_AUTHORIZATION', 'AUTHORIZE')).toBe(true);
  });

  it('keeps optional marketing out of quote readiness', () => {
    expect(
      isQuoteBlockingNotice({ category: 'MARKETING_OPTIONAL', requiredForQuote: false }),
    ).toBe(false);
    expect(consentActionSatisfiesNotice('MARKETING_OPTIONAL', 'OPT_IN')).toBe(false);
  });

  it('rejects configuration that makes marketing consent required for a quote', () => {
    expect(() =>
      assertNoticeRequirement({ category: 'MARKETING_OPTIONAL', requiredForQuote: true }),
    ).toThrow('MARKETING_NOTICE_CANNOT_BLOCK_QUOTE');
  });

  it('supports an explicit decline without treating it as authorization', () => {
    expect(isConsentActionValid('REPORT_AUTHORIZATION', 'DECLINE')).toBe(true);
    expect(consentActionSatisfiesNotice('REPORT_AUTHORIZATION', 'DECLINE')).toBe(false);
  });
});
