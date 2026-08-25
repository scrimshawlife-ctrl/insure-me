import { Routes } from '@angular/router';

export const QUOTING_ROUTES: Routes = [{
  path: '',
  loadComponent: () => import('../shared/ui/placeholder-page.component').then((m) => m.PlaceholderPageComponent),
  data: { title: 'Quote and carrier results' },
}];
