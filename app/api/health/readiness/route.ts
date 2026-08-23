import { NextResponse } from 'next/server';
import { assessDeploymentReadiness } from '@/src/infrastructure/config/deployment';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const readiness = assessDeploymentReadiness();
    const liveBlocked = readiness.stage !== 'synthetic' && !readiness.ready;

    return NextResponse.json(
      {
        status: liveBlocked ? 'blocked' : 'ready',
        stage: readiness.stage,
        blockers: readiness.blockers,
      },
      { status: liveBlocked ? 503 : 200 },
    );
  } catch {
    return NextResponse.json(
      {
        status: 'blocked',
        stage: 'unknown',
        blockers: ['DEPLOYMENT_CONTROL_ENVIRONMENT_INVALID'],
      },
      { status: 503 },
    );
  }
}
