import { InjectionToken } from '@angular/core';

export type ApiMode = 'canonical' | 'synthetic';

export interface RuntimeConfig {
  apiBaseUrl: string;
  apiMode: ApiMode;
}

export const RUNTIME_CONFIG = new InjectionToken<RuntimeConfig>('RUNTIME_CONFIG', {
  providedIn: 'root',
  factory: () => ({
    apiBaseUrl: '/api/v1',
    apiMode: 'canonical',
  }),
});

// Browser runtime config MUST contain only public, non-secret values.
// Server/provider/carrier/Supabase secret material is prohibited here.
