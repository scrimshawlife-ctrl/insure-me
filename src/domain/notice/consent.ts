export const NOTICE_CATEGORIES = [
  'INSURANCE_PRIVACY',
  'CONSUMER_REPORT_DISCLOSURE',
  'REPORT_AUTHORIZATION',
  'ELECTRONIC_COMMUNICATIONS',
  'NOTICE_AT_COLLECTION',
  'SMS_TRANSACTIONAL',
  'MARKETING_OPTIONAL',
] as const;

export type NoticeCategory = (typeof NOTICE_CATEGORIES)[number];

export const CONSENT_ACTIONS = [
  'ACKNOWLEDGE',
  'AUTHORIZE',
  'DECLINE',
  'WITHDRAW',
  'OPT_IN',
  'OPT_OUT',
] as const;

export type ConsentAction = (typeof CONSENT_ACTIONS)[number];

export interface NoticeRequirement {
  category: NoticeCategory;
  requiredForQuote: boolean;
}

const VALID_ACTIONS: Record<NoticeCategory, readonly ConsentAction[]> = {
  INSURANCE_PRIVACY: ['ACKNOWLEDGE'],
  CONSUMER_REPORT_DISCLOSURE: ['ACKNOWLEDGE'],
  REPORT_AUTHORIZATION: ['AUTHORIZE', 'DECLINE', 'WITHDRAW'],
  ELECTRONIC_COMMUNICATIONS: ['ACKNOWLEDGE'],
  NOTICE_AT_COLLECTION: ['ACKNOWLEDGE'],
  SMS_TRANSACTIONAL: ['OPT_IN', 'OPT_OUT', 'WITHDRAW'],
  MARKETING_OPTIONAL: ['OPT_IN', 'OPT_OUT', 'WITHDRAW'],
};

const SATISFYING_ACTIONS: Record<NoticeCategory, readonly ConsentAction[]> = {
  INSURANCE_PRIVACY: ['ACKNOWLEDGE'],
  CONSUMER_REPORT_DISCLOSURE: ['ACKNOWLEDGE'],
  REPORT_AUTHORIZATION: ['AUTHORIZE'],
  ELECTRONIC_COMMUNICATIONS: ['ACKNOWLEDGE'],
  NOTICE_AT_COLLECTION: ['ACKNOWLEDGE'],
  SMS_TRANSACTIONAL: ['OPT_IN'],
  MARKETING_OPTIONAL: [],
};

export function isConsentActionValid(
  category: NoticeCategory,
  action: ConsentAction,
): boolean {
  return VALID_ACTIONS[category].includes(action);
}

export function consentActionSatisfiesNotice(
  category: NoticeCategory,
  action: ConsentAction,
): boolean {
  return SATISFYING_ACTIONS[category].includes(action);
}

export function isQuoteBlockingNotice(requirement: NoticeRequirement): boolean {
  return requirement.requiredForQuote && requirement.category !== 'MARKETING_OPTIONAL';
}

export function assertNoticeRequirement(requirement: NoticeRequirement): void {
  if (requirement.category === 'MARKETING_OPTIONAL' && requirement.requiredForQuote) {
    throw new Error('MARKETING_NOTICE_CANNOT_BLOCK_QUOTE');
  }
}
