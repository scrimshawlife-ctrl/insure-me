const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

export function isMutationOriginAllowed(input: {
  method: string;
  requestOrigin: string | null;
  expectedOrigin: string;
  fetchSite: string | null;
}): boolean {
  if (SAFE_METHODS.has(input.method.toUpperCase())) return true;
  if (input.fetchSite === 'cross-site') return false;
  if (!input.requestOrigin) return input.fetchSite === null || input.fetchSite === 'same-origin';
  try {
    return new URL(input.requestOrigin).origin === new URL(input.expectedOrigin).origin;
  } catch {
    return false;
  }
}
