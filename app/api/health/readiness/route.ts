import { NextResponse } from 'next/server';
import { assessDeploymentReadiness } from '@/src/infrastructure/config/deployment';
import { readProviderHealthSnapshot } from '@/src/application/operations/provider-health';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const readiness = assessDeploymentReadiness();
    const providerHealth = readProviderHealthSnapshot();
    const liveProviderSnapshotMissing = readiness.stage !== 'synthetic' && providerHealth === null;
    const liveBlocked = readiness.stage !== 'synthetic'
      && (!readiness.ready || liveProviderSnapshotMissing || providerHealth?.quoteCompletionBlocked === true);
    const blockers = [
      ...readiness.blockers,
      ...(liveProviderSnapshotMissing ? ['PROVIDER_HEALTH_SNAPSHOT_MISSING'] : []),
      ...(providerHealth?.reasonCodes ?? []),
    ];

    return NextResponse.json(
      {
        status: liveBlocked ? 'blocked' : 'ready',
        stage: readiness.stage,
        blockers,
        components: { providers: providerHealth },
      },
      { status: liveBlocked ? 503 : 200 },
    );
  } catch (error) {
    const blocker = error instanceof Error && error.message.startsWith('PROVIDER_HEALTH_SNAPSHOT_')
      ? error.message
      : 'DEPLOYMENT_CONTROL_ENVIRONMENT_INVALID';
    return NextResponse.json(
      {
        status: 'blocked',
        stage: 'unknown',
        blockers: [blocker],
      },
      { status: 503 },
    );
  }
}
