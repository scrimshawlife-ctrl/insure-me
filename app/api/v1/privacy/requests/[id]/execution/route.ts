import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';

import {
  executePrivacyRightsRequest,
} from '@/src/application/privacy/privacy-rights-execution';
import { createSupabaseAdminClient } from '@/src/infrastructure/supabase/admin';

const requestIdSchema = z.uuid();
const statusTokenSchema = z.string().regex(/^[A-Za-z0-9_-]{43}$/);
const addressSchema = z.object({
  line1: z.string().trim().min(1).max(120),
  line2: z.string().trim().max(120).optional(),
  city: z.string().trim().min(1).max(80),
  state: z.literal('CA'),
  postalCode: z.string().regex(/^\d{5}(?:-\d{4})?$/),
}).strict();
const correctionsSchema = z.object({
  firstName: z.string().trim().min(1).max(80).optional(),
  lastName: z.string().trim().min(1).max(80).optional(),
  email: z.string().trim().email().max(254).optional(),
  phone: z.string().trim().min(7).max(30).optional(),
  address: addressSchema.optional(),
}).strict().refine((value) => Object.keys(value).length > 0);
const executionSchema = z.object({
  idempotencyKey: z.uuid(),
  corrections: correctionsSchema.nullable().optional(),
}).strict();

function response(error: string, status: number) {
  return NextResponse.json(
    { error },
    { status, headers: { 'Cache-Control': 'no-store' } },
  );
}

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const parsedId = requestIdSchema.safeParse(id);
  const parsedToken = statusTokenSchema.safeParse(
    request.headers.get('x-privacy-request-token'),
  );
  const parsedBody = executionSchema.safeParse(
    await request.json().catch(() => null),
  );
  if (!parsedId.success || !parsedToken.success || !parsedBody.success) {
    return response('PRIVACY_REQUEST_NOT_FOUND', 404);
  }
  try {
    const result = await executePrivacyRightsRequest(
      createSupabaseAdminClient(),
      {
        hostname: new URL(request.url).hostname.toLowerCase(),
        privacyRequestId: parsedId.data,
        statusToken: parsedToken.data,
        idempotencyKey: parsedBody.data.idempotencyKey,
        corrections: parsedBody.data.corrections ?? null,
      },
    );
    return NextResponse.json(result, {
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (message.includes('PRIVACY_RIGHTS_EXECUTION_POLICY_NOT_CONFIGURED')) {
      return response('PRIVACY_RIGHTS_EXECUTION_UNAVAILABLE', 503);
    }
    return response('PRIVACY_REQUEST_NOT_FOUND', 404);
  }
}
