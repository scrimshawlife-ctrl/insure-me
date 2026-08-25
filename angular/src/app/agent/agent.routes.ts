import { Routes } from '@angular/router';

export const AGENT_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () => import('../shared/ui/placeholder-page.component').then((m) => m.PlaceholderPageComponent),
    data: { title: 'Agent workspace' },
  },
  {
    path: 'quote-cases/:id',
    loadComponent: () => import('../shared/ui/placeholder-page.component').then((m) => m.PlaceholderPageComponent),
    data: { title: 'Agent quote case' },
  },
];
