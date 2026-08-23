export interface ConsumerQuoteContext {
  userId: string;
  quoteCaseId: string;
  tenantId: string;
  agencyId: string;
  accessExpiresAt: string;
}

export function assertConsumerQuoteContext(
  context: ConsumerQuoteContext,
  requestedQuoteCaseId: string,
): void {
  if (context.quoteCaseId !== requestedQuoteCaseId) {
    throw new Error('CONSUMER_QUOTE_CONTEXT_MISMATCH');
  }

  const expiresAt = Date.parse(context.accessExpiresAt);
  if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
    throw new Error('CONSUMER_QUOTE_ACCESS_EXPIRED');
  }
}
