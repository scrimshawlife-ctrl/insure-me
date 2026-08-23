import { NextResponse } from 'next/server';

import { getRequiredNotices } from '@/src/application/notice/get-required-notices';
import { requireConsumerQuoteContext } from '@/src/infrastructure/auth/consumer-context';
import { createSupabaseServerClient } from '@/src/infrastructure/supabase/server';

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id: quoteCaseId } = await context.params;
  const client = await createSupabaseServerClient();

  try {
    await requireConsumerQuoteContext(client, quoteCaseId);
    const notices = await getRequiredNotices(client, quoteCaseId);

    return NextResponse.json({ notices });
  } catch {
    return NextResponse.json(
      { error: 'CONSUMER_QUOTE_ACCESS_DENIED' },
      { status: 404 },
    );
  }
}
