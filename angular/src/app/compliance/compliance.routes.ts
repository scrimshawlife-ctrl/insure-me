import { Routes } from '@angular/router';

export const COMPLIANCE_ROUTES: Routes = [{
  path: '',
  loadComponent: () => import('../shared/ui/placeholder-page.component').then((m) => m.PlaceholderPageComponent),
  data: { title: 'Compliance workflows' },
}];
