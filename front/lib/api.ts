/**
 * Shared API client for the frontend. Every call that carries an
 * Authorization header should go through `apiFetch` so a 401 triggers the
 * refresh-token flow instead of dropping the user on the login screen:
 *
 *   1. `POST /api/auth/refresh` with the stored refresh token (single-flight —
 *      concurrent 401s share one refresh).
 *   2. On success the rotated pair is persisted and the original request is
 *      retried once with the fresh access token.
 *   3. On failure the session is cleared and the 401 response is returned so
 *      callers keep their existing "session expired" handling.
 */

export const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001';

export function authHeaders(): Record<string, string> {
  const token = typeof window === 'undefined' ? null : localStorage.getItem('token');
  return token ? { Authorization: `Bearer ${token}` } : {};
}

function sessionKeys(): string[] {
  return ['token', 'refresh_token', 'user'];
}

/** Persist the token pair + user blob returned by login/register/refresh. */
export function storeSession(data: {
  token: string;
  refresh_token?: string;
  user?: unknown;
}) {
  localStorage.setItem('token', data.token);
  if (data.refresh_token) localStorage.setItem('refresh_token', data.refresh_token);
  if (data.user) localStorage.setItem('user', JSON.stringify(data.user));
  window.dispatchEvent(new Event('localStorageUpdated'));
}

export function clearSession() {
  for (const key of sessionKeys()) localStorage.removeItem(key);
  window.dispatchEvent(new Event('localStorageUpdated'));
}

let refreshPromise: Promise<boolean> | null = null;

/** Rotate tokens. Single-flight: concurrent callers await the same request. */
export async function refreshTokens(): Promise<boolean> {
  if (typeof window === 'undefined') return false;
  const attempted = localStorage.getItem('refresh_token');
  if (!attempted) return false;
  if (!refreshPromise) {
    refreshPromise = (async () => {
      try {
        const res = await fetch(`${API_URL}/api/auth/refresh`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ refresh_token: attempted }),
        });
        if (res.ok) {
          const data = await res.json();
          localStorage.setItem('token', data.token);
          localStorage.setItem('refresh_token', data.refresh_token);
          return true;
        }
      } catch {
        /* fall through to the sibling-tab check below */
      }
      // The refresh may have failed because a sibling tab won the race to
      // rotate first (two tabs expiring together). Give that tab's rotation
      // a moment to land via the storage event, then adopt its pair instead
      // of giving up and signing out.
      await new Promise((resolve) => setTimeout(resolve, 750));
      const fresher = localStorage.getItem('refresh_token');
      if (fresher && fresher !== attempted) return true;
      return false;
    })();
    refreshPromise.finally(() => {
      refreshPromise = null;
    });
  }
  return refreshPromise;
}

export async function apiFetch(url: string, init: RequestInit = {}): Promise<Response> {
  const token =
    typeof window === 'undefined' ? null : localStorage.getItem('token');
  const hadAuth = Boolean(token);
  const headers = new Headers(init.headers ?? {});
  if (token) headers.set('Authorization', `Bearer ${token}`);

  let res = await fetch(url, { ...init, headers });

  if (res.status === 401 && hadAuth) {
    const renewed = await refreshTokens();
    if (renewed) {
      const retryHeaders = new Headers(init.headers ?? {});
      retryHeaders.set('Authorization', `Bearer ${localStorage.getItem('token')}`);
      res = await fetch(url, { ...init, headers: retryHeaders });
    } else {
      clearSession();
    }
  }
  return res;
}