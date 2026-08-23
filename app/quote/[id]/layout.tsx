import type { ReactNode } from 'react';

import { SaveResumeControl } from './save-resume-control';

export default async function ConsumerQuoteLayout({
  children,
  params,
}: {
  children: ReactNode;
  params: Promise<{ id: string }>;
}) {
  const { id: quoteCaseId } = await params;

  return (
    <>
      {children}
      <aside className="resume-dock" aria-label="Save quote for later">
        <SaveResumeControl quoteCaseId={quoteCaseId} />
      </aside>
    </>
  );
}
