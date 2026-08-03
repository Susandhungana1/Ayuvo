/**
 * Client for the caretaker endpoints, and the one place that builds a
 * `patient_id` query string.
 *
 * User ids contain a '#' (they look like "#hos014"). Interpolated raw into a
 * URL that character starts the fragment, so the parameter reaches the server
 * empty and the request silently scopes to the caller's own records instead —
 * a caretaker's edit landing on their own medicine list. Always go through
 * `scopedUrl`, never build these URLs by hand.
 */

export const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:3001';

export interface CareLink {
  id: string;
  user_id: string;
  name: string;
  created_at: string;
  notify: boolean;
  medicine_count?: number | null;
  next_dose_name?: string | null;
  /** The patient's wall clock ("08:00"). Never localise this — see the API. */
  next_dose_local?: string | null;
  next_dose_is_today?: boolean | null;
  next_dose_timezone?: string | null;
}

export interface AuditEntry {
  id: number;
  actor_id: string;
  actor_name: string;
  medicine_id: string | null;
  medicine_name: string | null;
  action: 'create' | 'update' | 'delete' | 'restore';
  created_at: string;
  by_caretaker: boolean;
}

/** Raised when a care link was revoked while the page was still open. */
export class CareAccessRevoked extends Error {
  constructor() {
    super('This care link is no longer active.');
    this.name = 'CareAccessRevoked';
  }
}

export function authHeaders(): Record<string, string> {
  const token = typeof window === 'undefined' ? null : localStorage.getItem('token');
  return token ? { Authorization: `Bearer ${token}` } : {};
}

/** Build `path`, appending a correctly-encoded patient_id when scoping. */
export function scopedUrl(path: string, patientId?: string | null): string {
  const url = `${API_URL}${path}`;
  if (!patientId) return url;
  const sep = path.includes('?') ? '&' : '?';
  return `${url}${sep}patient_id=${encodeURIComponent(patientId)}`;
}

async function request<T>(url: string, init: RequestInit = {}): Promise<T> {
  const res = await fetch(url, {
    ...init,
    headers: {
      ...authHeaders(),
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...(init.headers || {}),
    },
  });

  // 403 on a scoped call means the patient revoked the link mid-session.
  if (res.status === 403) throw new CareAccessRevoked();
  if (!res.ok) {
    const detail = await res.json().catch(() => null);
    throw new Error(detail?.detail || 'Request failed');
  }
  return res.status === 204 ? (null as T) : res.json();
}

export async function listLinks(role: 'patient' | 'caretaker'): Promise<CareLink[]> {
  const data = await request<{ links: CareLink[] }>(
    `${API_URL}/api/care/links?role=${role}`,
  );
  return data.links || [];
}

export async function createInvite(): Promise<{ code: string; expires_at: string }> {
  return request(`${API_URL}/api/care/invites`, { method: 'POST' });
}

export async function redeemInvite(code: string): Promise<CareLink> {
  return request(`${API_URL}/api/care/invites/redeem`, {
    method: 'POST',
    body: JSON.stringify({ code }),
  });
}

export async function setNotify(linkId: string, notify: boolean): Promise<CareLink> {
  return request(`${API_URL}/api/care/links/${linkId}`, {
    method: 'PATCH',
    body: JSON.stringify({ notify }),
  });
}

export async function revokeLink(linkId: string): Promise<void> {
  await request(`${API_URL}/api/care/links/${linkId}`, { method: 'DELETE' });
}

export async function listAudit(patientId?: string): Promise<AuditEntry[]> {
  const data = await request<{ entries: AuditEntry[] }>(
    scopedUrl('/api/medicines/audit', patientId),
  );
  return data.entries || [];
}

export async function restoreMedicine(
  medicineId: string,
  patientId?: string,
): Promise<void> {
  await request(scopedUrl(`/api/medicines/${medicineId}/restore`, patientId), {
    method: 'POST',
  });
}

/** Whether the caretaker feature is reachable — the API 404s while it's off. */
export async function careEnabled(): Promise<boolean> {
  try {
    const res = await fetch(`${API_URL}/api/care/links?role=caretaker`, {
      headers: authHeaders(),
    });
    return res.status !== 404;
  } catch {
    return false;
  }
}
