export const noticeCategories = [
  'INSURANCE_PRIVACY', 'CONSUMER_REPORT_DISCLOSURE', 'REPORT_AUTHORIZATION',
  'ELECTRONIC_COMMUNICATIONS', 'NOTICE_AT_COLLECTION', 'SMS_TRANSACTIONAL',
  'MARKETING_OPTIONAL', 'ADVERSE_ACTION',
] as const;

export type NoticeCategory = typeof noticeCategories[number];
export type NoticeStatus = 'DRAFT' | 'SYNTHETIC' | 'APPROVED' | 'RETIRED';

export interface NoticeDefinitionVersion {
  noticeDefinitionId: string;
  noticeKey: string;
  version: number;
  status: NoticeStatus;
  category: NoticeCategory;
  jurisdiction: 'CA';
  productLine: 'PRIVATE_PASSENGER_AUTO';
  title: string;
  bodyMarkdown: string;
  contentHash: string;
  requiredForQuote: boolean;
  effectiveAt: string | null;
  retiredAt: string | null;
  approvedAt: string | null;
  approvalRef: string | null;
  createdAt: string;
}
