export type SecurityEventType = 'PROVIDER_ORDER_RATE_LIMITED' | 'PROVIDER_ORDER_DENIED' | 'PROVIDER_ORDER_FAILED';

export interface SecurityTelemetryEvent {
  eventType: SecurityEventType;
  outcome: 'DENIED' | 'FAILED';
  routeCategory: 'PROVIDER_ORDER';
  tenantId: string;
  actorId: string;
  reasonCodes: string[];
}

const SAFE_CODE = /^[A-Z0-9_:-]{1,120}$/;
const OPAQUE_ID = /^[0-9a-f-]{36}$/i;

export function serializeSecurityTelemetry(event: SecurityTelemetryEvent): string {
  if (!OPAQUE_ID.test(event.tenantId) || !OPAQUE_ID.test(event.actorId)) throw new Error('SECURITY_TELEMETRY_ID_INVALID');
  const reasonCodes = event.reasonCodes.filter((code) => SAFE_CODE.test(code)).slice(0, 12);
  return JSON.stringify({
    schemaVersion: 'security-event-v1',
    eventType: event.eventType,
    outcome: event.outcome,
    routeCategory: event.routeCategory,
    tenantId: event.tenantId,
    actorId: event.actorId,
    reasonCodes,
  });
}

export function logSecurityTelemetry(event: SecurityTelemetryEvent): void {
  console.info(serializeSecurityTelemetry(event));
}
