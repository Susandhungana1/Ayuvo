/**
 * Claimed shares — "Shared with me".
 *
 * A share link is a bearer token that expires. Claiming one keeps what it
 * showed you, so the access outlives the link. Claiming grants the recipient
 * nothing new (the reader is open in front of them); it trades their anonymity
 * for persistence, which is why the owner gets a list of who claimed.
 *
 * Auth mirrors lib/care.ts: bearer token from localStorage, 401 clears it.
 */

import { API_URL, SessionExpired, authHeaders } from './care';

export interface ReceivedShare {
  id: string;
  kind: 'report' | 'all';
  owner_name: string;
  owner_id: string;
  report_count: number;
  claimed_at: string;
}

export interface SharedReport {
  id: string;
  report_type: string;
  file_name: string;
  file_content: string;
  notes?: string | null;
  extracted_text?: string | null;
  doctor_name?: string | null;
  hospital?: string | null;
  created_at?: string | null;
}

export interface ReceivedShareDetail {
  id: string;
  owner_name: string;
  owner_id: string;
  kind: 'report' | 'all';
  claimed_at: string;
  reports: SharedReport[];
  /** Reports present at claim time that the owner has since deleted. */
  withdrawn_count: number;
}

export interface ClaimOnMyRecords {
  id: string;
  recipient_name: string;
  recipient_id: string;
  kind: 'report' | 'all';
  report_count: number;
  claimed_at: string;
  status: string;
}

export function isSignedIn(): boolean {
  return typeof window !== 'undefined' && !!localStorage.getItem('token');
}

/**
 * Subscribe to sign-in/sign-out, for useSyncExternalStore.
 *
 * The session lives in localStorage, which does not exist during SSR, so it
 * cannot be read while rendering without a hydration mismatch. `storage` fires
 * for other tabs; `localStorageUpdated` is this app's own same-tab signal,
 * dispatched by lib/care.ts when a dead token is cleared.
 */
export function subscribeToSession(onChange: () => void): () => void {
  window.addEventListener('storage', onChange);
  window.addEventListener('localStorageUpdated', onChange);
  return () => {
    window.removeEventListener('storage', onChange);
    window.removeEventListener('localStorageUpdated', onChange);
  };
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, {
    ...init,
    headers: { ...authHeaders(), ...(init.headers || {}) },
  });

  if (res.status === 401) {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.dispatchEvent(new Event('localStorageUpdated'));
    }
    throw new SessionExpired();
  }
  if (!res.ok) {
    const detail = await res.json().catch(() => null);
    throw new Error(detail?.detail || `Request failed (HTTP ${res.status})`);
  }
  return res.json();
}

/** Keep a share you are currently able to read. Idempotent. */
export function claimShare(token: string): Promise<ReceivedShare> {
  return request(`/api/share/${encodeURIComponent(token)}/claim`, { method: 'POST' });
}

export async function listReceivedShares(): Promise<ReceivedShare[]> {
  const data = await request<{ shares: ReceivedShare[] }>('/api/share/received');
  return data.shares || [];
}

export function readReceivedShare(claimId: string): Promise<ReceivedShareDetail> {
  return request(`/api/share/received/${encodeURIComponent(claimId)}`);
}

/** Recipient removes a share from their own list. */
export function dropReceivedShare(claimId: string): Promise<{ message: string }> {
  return request(`/api/share/received/${encodeURIComponent(claimId)}`, {
    method: 'DELETE',
  });
}

/** Who has kept a copy of *your* records. */
export async function listClaimsOnMyRecords(): Promise<ClaimOnMyRecords[]> {
  const data = await request<{ claims: ClaimOnMyRecords[] }>('/api/share/claims');
  return data.claims || [];
}

/** Owner withdraws someone's kept copy. */
export function revokeClaim(claimId: string): Promise<{ message: string }> {
  return request(`/api/share/claims/${encodeURIComponent(claimId)}`, {
    method: 'DELETE',
  });
}
