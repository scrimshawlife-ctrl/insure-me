import { Routes } from '@angular/router';

export const appRoutes: Routes = [
  {
    path: '',
    loadComponent: () => import('./shared/ui/placeholder-page.component').then((m) => m.PlaceholderPageComponent),
    data: { title: 'Insure Me Angular shell' },
  },
  { path: 'quote', loadChildren: () => import('./applicant/applicant.routes').then((m) => m.APPLICANT_ROUTES) },
  { path: 'quotes', loadChildren: () => import('./quoting/quoting.routes').then((m) => m.QUOTING_ROUTES) },
  { path: 'evidence', loadChildren: () => import('./evidence/evidence.routes').then((m) => m.EVIDENCE_ROUTES) },
  { path: 'compliance', loadChildren: () => import('./compliance/compliance.routes').then((m) => m.COMPLIANCE_ROUTES) },
  { path: 'agent', loadChildren: () => import('./agent/agent.routes').then((m) => m.AGENT_ROUTES) },
  { path: 'admin', loadChildren: () => import('./admin/admin.routes').then((m) => m.ADMIN_ROUTES) },
  { path: '**', redirectTo: '' },
];
