import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import { orchestrateProviderRequest } from '@/src/application/providers/orchestrate-provider-request';
import type { ProviderCapability } from '@/src/domain/providers';
import type { WorkforceContext } from '@/src/domain/auth/workforce';
import { requireWorkforceContext } from '@/src/infrastructure/auth/workforce-context';
import { resolveProviderAdapter } from '@/src/infrastructure/providers/provider-registry';
import { resolveProviderRequestContext } from '@/src/infrastructure/providers/provider-request-context';
import { SupabaseProviderOrchestrationPersistence } from '@/src/infrastructure/providers/supabase-provider-persistence';
import { SupabaseProviderPreflightPolicy } from '@/src/infrastructure/providers/supabase-provider-preflight-policy';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';
import { logSecurityTelemetry } from '@/src/infrastructure/security/security-telemetry';
import { recordWorkforceSecuritySignal } from '@/src/infrastructure/security/workforce-security-signals';

const requestSchema = z.object({
  capability: z.enum(['IDENTITY', 'PREFILL', 'MVR', 'CLAIMS', 'VEHICLE']),
  subjectIds: z.array(z.string().uuid()).max(12),
  idempotencyKey: z.string().min(8).max(160),
});

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id: quoteCaseId } = await context.params;
  const parsed = requestSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: 'REQUEST_VALIDATION_FAILED' }, { status: 400 });
  }

  const userClient = await createSupabaseServerClient();
  let workforce: WorkforceContext | null = null;

  try {
    workforce = await requireWorkforceContext(userClient);
    const rate = await recordWorkforceSecuritySignal({
      workforce,
      signalType: 'PROVIDER_ORDER_ATTEMPT',
      limit: 20,
      windowSeconds: 60,
    });
    if (!rate.allowed) {
      logSecurityTelemetry({
        eventType: 'PROVIDER_ORDER_RATE_LIMITED', outcome: 'DENIED', routeCategory: 'PROVIDER_ORDER',
        tenantId: workforce.tenantId, actorId: workforce.userId, reasonCodes: ['RATE_LIMIT_EXCEEDED'],
      });
      return NextResponse.json({ error: 'RATE_LIMIT_EXCEEDED' }, { status: 429 });
    }
    const resolved = await resolveProviderRequestContext({
      userClient,
      workforce,
      quoteCaseId,
      capability: parsed.data.capability as ProviderCapability,
      subjectIds: parsed.data.subjectIds,
      idempotencyKey: parsed.data.idempotencyKey,
    });

    const adapter = resolveProviderAdapter({
      adapterId: resolved.adapterId,
      adapterVersion: resolved.adapterVersion,
      capability: parsed.data.capability,
    });
    const policy = new SupabaseProviderPreflightPolicy({
      adapterId: resolved.adapterId,
      adapterVersion: resolved.adapterVersion,
      purposeCode: resolved.configuredPurposeCode,
      requiresReportAuthorization: resolved.requiresReportAuthorization,
    });
    const persistence = new SupabaseProviderOrchestrationPersistence();

    // Synthetic runtime always selects the deterministic success fixture here.
    // Failure/no-hit/stale scenarios remain test-harness concerns and are never client-controlled.
    const result = await orchestrateProviderRequest({
      adapter,
      persistence,
      policy,
      context: resolved.context,
      request: { scenario: 'SUCCESS' },
    });

    return NextResponse.json({
      status: result.status,
      providerRequestId: result.providerRequestId ?? null,
      providerReportId: result.providerReportId ?? null,
      warnings: result.warnings,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'PROVIDER_REQUEST_FAILED';
    if (message.startsWith('WORKFORCE_') || message === 'ACTIVE_TENANT_REQUIRED') {
      return NextResponse.json({ error: message }, { status: 403 });
    }
    if (message.startsWith('PROVIDER_REQUEST_BLOCKED:')) {
      const reasonCodes = message.slice('PROVIDER_REQUEST_BLOCKED:'.length).split(',').filter(Boolean);
      if (workforce) {
        await recordWorkforceSecuritySignal({
          workforce, signalType: 'DENIED_LOOKUP', limit: 5, windowSeconds: 300, reasonCodes,
        }).catch(() => undefined);
        logSecurityTelemetry({
          eventType: 'PROVIDER_ORDER_DENIED', outcome: 'DENIED', routeCategory: 'PROVIDER_ORDER',
          tenantId: workforce.tenantId, actorId: workforce.userId, reasonCodes,
        });
      }
      return NextResponse.json(
        {
          error: 'PROVIDER_REQUEST_BLOCKED',
          reasonCodes,
        },
        { status: 409 },
      );
    }
    if (
      message === 'QUOTE_CASE_NOT_FOUND' ||
      message === 'PROVIDER_BINDING_NOT_ACTIVE'
    ) {
      return NextResponse.json({ error: 'NOT_FOUND' }, { status: 404 });
    }
    if (workforce) {
      logSecurityTelemetry({
        eventType: 'PROVIDER_ORDER_FAILED', outcome: 'FAILED', routeCategory: 'PROVIDER_ORDER',
        tenantId: workforce.tenantId, actorId: workforce.userId, reasonCodes: ['PROVIDER_REQUEST_FAILED'],
      });
    }
    return NextResponse.json({ error: 'PROVIDER_REQUEST_FAILED' }, { status: 500 });
  }
}
