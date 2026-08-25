import { Routes } from '@angular/router';

export const APPLICANT_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () => import('../shared/ui/placeholder-page.component').then((m) => m.PlaceholderPageComponent),
    data: { title: 'Applicant quote workflow' },
  },
  {
    path: ':id',
    loadComponent: () => import('../shared/ui/placeholder-page.component').then((m) => m.PlaceholderPageComponent),
    data: { title: 'Applicant quote case' },
  },
];
