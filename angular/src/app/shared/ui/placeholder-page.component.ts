import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';

@Component({
  selector: 'im-placeholder-page',
  standalone: true,
  template: `
    <main class="page-shell">
      <p class="eyebrow">Migration workspace</p>
      <h1>{{ title }}</h1>
      <p>This route boundary is intentionally a shell until its canonical HTTP contracts are executable.</p>
    </main>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PlaceholderPageComponent {
  private readonly route = inject(ActivatedRoute);
  readonly title = String(this.route.snapshot.data['title'] ?? 'Insure Me');
}
