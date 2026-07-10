export interface CalendarEvent {
  id: string;
  title: string;
  description?: string;
  location?: string;
  start: string | Date; // ISO string or Date
  durationMinutes?: number;
}

/** Format a Date as an iCalendar UTC timestamp: YYYYMMDDTHHMMSSZ */
function toIcsUtc(d: Date): string {
  return d.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
}

/** Escape text per RFC 5545 (commas, semicolons, backslashes, newlines). */
function escapeText(s: string): string {
  return s.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\n/g, '\\n');
}

/** Build a valid single-event .ics document string. */
export function buildIcs(event: CalendarEvent): string {
  const start = event.start instanceof Date ? event.start : new Date(event.start);
  const end = new Date(start.getTime() + (event.durationMinutes ?? 30) * 60000);
  const now = new Date();

  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//MediStore//Appointments//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:${event.id}@medistore`,
    `DTSTAMP:${toIcsUtc(now)}`,
    `DTSTART:${toIcsUtc(start)}`,
    `DTEND:${toIcsUtc(end)}`,
    `SUMMARY:${escapeText(event.title)}`,
    event.description ? `DESCRIPTION:${escapeText(event.description)}` : '',
    event.location ? `LOCATION:${escapeText(event.location)}` : '',
    'BEGIN:VALARM',
    'TRIGGER:-PT1H',
    'ACTION:DISPLAY',
    `DESCRIPTION:${escapeText('Reminder: ' + event.title)}`,
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
  ].filter(Boolean);

  // RFC 5545 requires CRLF line endings.
  return lines.join('\r\n');
}

/** Generate an .ics file for the event and trigger a browser download. */
export function downloadIcs(event: CalendarEvent): void {
  const ics = buildIcs(event);
  const blob = new Blob([ics], { type: 'text/calendar;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  const safeName = event.title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '') || 'appointment';
  a.href = url;
  a.download = `${safeName}.ics`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
