/**
 * Timestamps from the API, parsed correctly.
 *
 * Most of the backend stamps rows with `datetime.utcnow()` — a *naive* UTC
 * value — and serialises it with `str(dt)` or bare Pydantic ISO, so it arrives
 * with no `Z` and no offset:
 *
 *     "2026-08-06 09:14:22.841913"   vitals, timeline, search
 *     "2026-08-07T09:14:22"          share link expiry
 *
 * `new Date(...)` reads both of those as *local* time, which in Asia/Kathmandu
 * puts every rendered timestamp 5h45m out. These helpers pin them to UTC.
 *
 * Two kinds of value must NOT go through `parseServerUtc`:
 *
 *   - `appointment_date` — the client sends a naive *local* datetime and the
 *     server stores it verbatim, so reading it back as local is correct.
 *   - date-only strings such as `medicines.start_date` ("2026-08-06"), which
 *     `new Date` parses as UTC midnight and then renders as the previous day
 *     anywhere west of Greenwich. Use `formatPlainDate` for those.
 *
 * Values that already carry a zone are left alone: the caretaker endpoints go
 * through `utc_iso()` server-side and append a real `Z`.
 */

const HAS_ZONE = /(?:Z|[+-]\d{2}:?\d{2})$/;

export function parseServerUtc(value?: string | null): Date | null {
  if (!value) return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  const iso = trimmed.replace(' ', 'T');
  const date = new Date(HAS_ZONE.test(trimmed) ? iso : `${iso}Z`);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function formatServerDateTime(value?: string | null): string {
  return parseServerUtc(value)?.toLocaleString() ?? '—';
}

export function formatServerDate(value?: string | null): string {
  return parseServerUtc(value)?.toLocaleDateString() ?? '—';
}

export function formatServerTimeOfDay(value?: string | null): string {
  return (
    parseServerUtc(value)?.toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
    }) ?? ''
  );
}

/** A date-only value ("2026-08-06"), rendered with no timezone shift at all. */
export function formatPlainDate(value?: string | null): string {
  if (!value) return '—';
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value.trim());
  if (!match) return value;
  const [, y, m, d] = match;
  return new Date(Number(y), Number(m) - 1, Number(d)).toLocaleDateString();
}

/** True once `value` (a naive-UTC timestamp) is in the past. */
export function hasExpired(value?: string | null): boolean {
  const date = parseServerUtc(value);
  return date !== null && date.getTime() <= Date.now();
}
