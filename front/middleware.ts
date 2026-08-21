import { NextRequest, NextResponse } from "next/server";

/**
 * Nonce-based Content-Security-Policy.
 *
 * The API already sends its own hardening headers; this is the frontend's half
 * of the bargain — a real CSP that blocks inline XSS instead of the "mostly
 * decorative" `'unsafe-inline'` version. Next.js reads the nonce out of the
 * CSP request header and applies it to every inline script/style it emits
 * during SSR, so `strict-dynamic` works without breaking hydration. The root
 * layout is `force-dynamic` for exactly this reason: statically-prerendered
 * pages have no request headers at build time, so they can never carry a
 * nonce.
 *
 * Deliberately applied only in production: in `next dev` the CSP is skipped
 * entirely so fast refresh and eval-based dev tooling are never the thing that
 * fails. `next build && next start` gets the full policy, matching what Vercel
 * serves.
 */

const API_ORIGIN = process.env.NEXT_PUBLIC_API_URL || "http://127.0.0.1:3001";

function buildCsp(nonce: string): string {
  return [
    "default-src 'self'",
    // strict-dynamic: scripts loaded by a nonce'd script inherit trust, so the
    // rest of the allowlist matters only for old browsers that ignore it.
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'`,
    `style-src 'self' 'nonce-${nonce}'`,
    // React/Leaflet/recharts set element style attributes at runtime; those
    // cannot run code, so allow them while keeping <style> blocks nonce-only.
    "style-src-attr 'unsafe-inline'",
    // OSM tiles + Supabase-hosted report images.
    "img-src 'self' data: blob: https://*.tile.openstreetmap.org https://*.supabase.co",
    // The API + the Overpass mirrors used by the Nearby Care map.
    `connect-src 'self' ${API_ORIGIN} https://overpass-api.de https://overpass.kumi.systems https://maps.mail.ru https://*.supabase.co`,
    "font-src 'self' data:",
    "worker-src 'self' blob:",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'self'",
  ].join("; ");
}

export function middleware(request: NextRequest) {
  if (process.env.NODE_ENV !== "production") {
    return NextResponse.next();
  }

  // Middleware runs on the Edge runtime, which has no Node `crypto`/`Buffer`
  // — the Web Crypto API is the portable path (available on Edge and Node).
  const nonceBytes = new Uint8Array(18);
  crypto.getRandomValues(nonceBytes);
  const nonce = btoa(String.fromCharCode(...nonceBytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
  const csp = buildCsp(nonce);

  // Next.js 16 extracts the nonce from the CSP header itself while rendering,
  // so it must be on the request headers — not just the response. `x-nonce` is
  // kept too for any component that wants to read it via `headers()`.
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-nonce", nonce);
  requestHeaders.set("content-security-policy", csp);

  const response = NextResponse.next({ request: { headers: requestHeaders } });
  response.headers.set("Content-Security-Policy", csp);
  return response;
}

export const config = {
  matcher: [
    // Only HTML document navigations need the header. Skipping static assets,
    // API route handlers and other non-HTML files keeps the free-tier cost down
    // and avoids a CSP header on JSON/JS/CSS responses.
    "/((?!api|_next/static|_next/image|favicon.ico|manifest.webmanifest|sw.js|offline.html|robots.txt|sitemap.xml|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico|txt|json|webmanifest)$).*)",
  ],
};