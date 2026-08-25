import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterLink, RouterOutlet } from '@angular/router';

@Component({
  selector: 'im-root',
  standalone: true,
  imports: [RouterLink, RouterOutlet],
  template: `
    <header class="app-header">
      <a class="brand" routerLink="/">Insure Me</a>
      <span class="migration-badge">Angular migration shell</span>
    </header>
    <router-outlet />
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppComponent {}
