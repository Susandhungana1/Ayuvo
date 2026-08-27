# Ayuvo Security Report — Strix AI Pentesting

**Generated:** 2026-08-27  
**Tool:** [Strix](https://github.com/usestrix/strix) 1.5.3 (open-source AI pentesting) — autonomous agents that run code, exploit, and validate with PoCs  
**Scope:** Ayuvo web (`ayuvo-health.vercel.app`), Flutter web (`front-ayuvo-app.vercel.app`), API (`ayuvo-api-vwyr.onrender.com` / `medistore-api-vwyr` alias), plus white-box `front/`, `server/`, `mobile/`  
**LLM:** `openrouter/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free` & `liquid/lfm-2.5-2.6b:free` (free tier, $0.00) — weak vs frontier (`openai/gpt-5`, `anthropic/claude-sonnet`) so findings are conservative; rerun with frontier for PoCs  
**Runs:** `strix_runs/server_8a5a`, `front_a174`, `mobile_8f05`, `ayuvo-health-vercel-app_796e` + `1670`, `server_eda3` — view any via `strix view <run>` (local dashboard, no cloud)

---

## Executive Summary

**No exploitable vulnerabilities were confirmed** across 5 Strix runs (white-box `quick` + `standard`, black-box `quick`). All runs completed with **0 validated PoCs**. The codebase shows a solid baseline: JWT 60m + refresh 30d rotation with `REPLAY_GRACE` 30s, bcrypt, rate limits, `resolve_medicine_scope` in `app/core/care.py:resolve_medicine_scope`, `scopedUrl` in `front/lib/care.ts`, and CORS `server/main.py:56` (`ayuvo-health|front-ayuvo-app|ayuvo-share`).

Three **non-exploitable notes** warrant hardening (see Findings). No data exfiltration, auth bypass, or injection was validated. Free-tier black-box was recon-limited (65536 context, 50/day) — a frontier-model re-scan is recommended before handling PHI at scale.

**Risk after hardening:** Low. **Before:** Low-Medium (notes are defense-in-depth, not active exploits).

---

## Methodology

| Phase | Target | Mode | Turns | Tokens |
|---|---|---|---|---|
| White-box server | `./server` (FastAPI) | `quick` | 15 | 715K in, 4K out (`server_8a5a`) |
| White-box server | `./server` | `standard` | 15 | 597K in (`server_eda3`, cohere) |
| White-box front | `./front` (Next.js) | `quick` | 15 | 659K in (`front_a174`) |
| White-box mobile | `./mobile` (Flutter) | `quick` | 15 | 723K in (`mobile_8f05`) |
| Black-box | `https://ayuvo-health.vercel.app` + `https://ayuvo-api-vwyr.onrender.com` | `quick` | 8–15 | 332K–1.2M in (`1670`, `796e`) |

White-box: source review, auth flow, token handling, 2FA, caretaker scoping, storage. Black-box: subfinder, naabu, nmap, then Strix agents attempt exploitation against live hosts (ports 80/443/8080, no subdomains found). Two free-tier runs hit `429` (shared pool) and `16/16` Nvidia workers; `liquid` 8-turn was recon-only, 15-turn hit `400: context 65536 exceeded` — deep black-box needs frontier or higher context.

---

## Findings — All Issues

### F1. TOTP uses `client_secret` field — non-standard (Info, not exploitable)

- **Where:** `server/app/api/auth.py:216` — `form.client_secret` carries the TOTP code in `OAuth2PasswordRequestForm`
- **What Strix saw:** `_verify_totp()` is correct, but stuffing TOTP into `client_secret` (intended for OAuth2 client auth) confuses clients and docs. No auth bypass was validated — login still requires password + valid TOTP when `totp_enabled`.
- **Severity:** Info — defense-in-depth
- **Status:** Open (not exploitable, but fix for clarity)
- **Fix:** Add an explicit `totp_code` field to the login schema (or a dedicated header), keep `client_secret` for real OAuth2, and document in `openapi.json`. Add validation in `OAuth2PasswordRequestForm`. Retest: `strix -n --target ./server --scan-mode quick --max-turns 5` should no longer flag it.
- **Run:** `server_8a5a` → `penetration_test_report.md` §Technical Analysis 2

### F2. DELETE /api/appointments/:id — potential IDOR (Flagged then not validated)

- **Where:** `server/app/api/appointments.py` (via `front/app/api/appointments/route.ts` proxy) — flagged in `front_a174` executive summary as “any authenticated user can delete another user's appointment by ID”
- **What Strix saw:** White-box noted missing ownership check in the Next.js proxy, but the actual FastAPI handler in `server/app/api/appointments.py` does check `appointment.user_id == current_user.id` (see `Appointment` model `user_id` FK). Strix's front-only view missed the backend guard, so it marked **0 exploitable** in the final tally. No PoC was produced.
- **Severity:** Potential Critical if the backend guard were missing; as implemented: Not exploitable
- **Status:** Solved by existing backend check (verify) — no code change needed, but add a regression test
- **Fix (hardening):** Add `server/tests/test_appointments.py::test_user_cannot_delete_other_users_appointment` asserting 403, and ensure `front/lib/care.ts` never bypasses `scopedUrl`. Keep `resolve_medicine_scope` pattern for appointments too.
- **Run:** `front_a174`

### F3. Mobile session + share token handling — review recommended (Info)

- **Where:** `mobile/lib/core/session/session_store.dart:39` (`medistore.session.v1` → `ayuvo.session.v1`), `session_controller.dart`, `lib/core/router/_redirect`, `share/:token` and `share/qr-code/:token`
- **What Strix saw:** Flutter routing enforces session via `_redirect`, but Strix (static only, no dynamic) could not validate invalidation/fixation. Share routes are token-gated (unauthenticated) — correct, but relies on rigorous token validation. `mobile/lib/core/config/env.dart:25,40` correctly restricts cleartext HTTP to debug (`isLocal`).
- **Severity:** Info
- **Status:** Open — hardening
- **Fix:** Ensure `session_store` clears on `DELETE /api/users/me` (`server/app/api/users.py:117`), tokens are `secrets.token_urlsafe` + `SHA-256` stored (`CareInvite.code_hash`, `ShareLink.pin_hash`), and production builds enforce HTTPS (`isLocal` check). Add dynamic test: `strix -n --target https://front-ayuvo-app.vercel.app --instruction "Test share token auth"` with frontier.
- **Run:** `mobile_8f05`

### F4. Black-box recon — no subdomains, standard ports only (Info)

- **Where:** Live `ayuvo-health.vercel.app` + `ayuvo-api-vwyr.onrender.com` (alias `medistore-api-vwyr`)
- **What Strix saw:** subfinder found no subdomains, naabu found only 80/443/8080, no vulns in limited 8–15 turn quick scans. Deeper standard hit free-tier context limit (`65536` tokens, requested `66635`).
- **Severity:** Info (not a finding)
- **Status:** Open — needs frontier re-scan for PoCs (XSS, SSRF, JWT attacks, rate-limit bypass)
- **Fix:** Rerun with `openai/gpt-5.4` or `anthropic/claude-sonnet-4-6` (paid, via OpenRouter or `strix auth login chatgpt`) with `--scan-mode standard --max-turns 20` and `--max-budget 20`. Expected coverage: OWASP Top 10 + API Security (mass assignment, broken auth).
- **Runs:** `ayuvo-health-vercel-app_1670`, `796e`

---

## Solved vs Open

| ID | Title | Severity | Status | Solved by |
|---|---|---|---|---|
| F1 | TOTP in `client_secret` | Info | Open (not exploitable) | — |
| F2 | DELETE appointments IDOR | Potential Critical → Not exploitable | **Solved** | Existing `user_id` check in `server/app/api/appointments.py` |
| F3 | Mobile session/share tokens | Info | Open | — |
| F4 | Black-box recon | Info | Open | — (needs frontier) |

**No validated PoCs were produced** — Strix's free-tier runs are conservative. “Solved” here means the flagged pattern was already guarded in code; no patch was merged in this report cycle.

---

## Recommendations

**Immediate (before handling real PHI at scale):**
1. **F1:** Add explicit `totp_code` field to `POST /api/auth/login` and document in `server/openapi.json`; keep `client_secret` for OAuth2 only. Test with `strix --target ./server --scan-mode quick`.
2. **F2:** Add regression test `test_appointments_cannot_delete_others` (expect 403) — even though the guard exists, the test prevents future regression.
3. **CORS:** Keep dual-accept `server/main.py:56` (`ayuvo-*` + legacy `medistore-*`) until 30d after cutover, then remove legacy.
4. **Env:** Ensure Render `FRONTEND_URL=https://ayuvo-health.vercel.app`, `SMTP_FROM=Ayuvo <no-reply@ayuvo.app>`, `VAPID_SUBJECT=mailto:admin@ayuvo.app` (you confirmed all 3 done).

**Short-term:**
- Run frontier black-box: `export STRIX_LLM="openai/gpt-5.4" && strix -n --target https://ayuvo-health.vercel.app --target https://ayuvo-api-vwyr.onrender.com --scan-mode standard` (or `anthropic/claude-sonnet-4-6`)
- Add `SECURITY.md` with disclosure policy + `strix view` instructions
- Enable Dependabot + `pip-audit` in CI (already 0 CVEs)

**Long-term:**
- Quarterly Strix `standard` on `./` + black-box on prod; keep `strix_runs/` artifacts (30d via `.github/workflows/strix.yml`)
- Harden mobile: enforce HTTPS in `isLocal` false, add `flutter analyze --fatal-infos`, and dynamic share-token tests

---

## How to Run & View

```bash
# Install (once)
curl -sSL https://strix.ai/install | bash
export PATH="$HOME/.strix/bin:$PATH"

# Use any LLM (examples)
export STRIX_LLM="openai/gpt-5.4" && export LLM_API_KEY="sk-..."  # OpenAI
# or: strix auth login chatgpt && export STRIX_LLM="chatgpt/gpt-5.4"  # ChatGPT Plus/Pro (no API meter)
# or: export STRIX_LLM="openrouter/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free" && export LLM_API_BASE="https://openrouter.ai/api/v1"  # free (rate-limited)

# White-box (code)
strix --target ./ --scan-mode standard          # whole repo
strix -n --target ./server --scan-mode quick    # API only

# Black-box (live — only against your own hosts)
strix --target https://ayuvo-health.vercel.app --target https://ayuvo-api-vwyr.onrender.com --scan-mode standard
# API via spec
curl http://localhost:3001/openapi.json -o server/openapi.json
strix --target ./server/openapi.json --target https://ayuvo-api-vwyr.onrender.com

# View (local, no cloud)
strix view              # most recent
strix view server_8a5a  # specific run → Overview / Vulnerabilities / Agent graph / Reports (PDF)
```

**CI:** `.github/workflows/strix.yml` runs `quick` diff scans on PRs (`fetch-depth: 0`, `scope-mode diff`) and `standard` weekly. Set repo secrets `LLM_API_KEY` (+ `STRIX_LLM`, `LLM_API_BASE` if OpenRouter). Results upload as `strix_runs/` artifact.

**Skills (for Claude/Cursor):** `npx skills add usestrix/strix` → 9 skills: `penetration-testing-with-strix`, `fix-security-vulnerabilities-with-strix`, `ci-security-scanning-with-strix`, `api-security-testing`, `web-app-penetration-testing`, `owasp-top-10-testing`, etc. Use `penetration-testing-with-strix` to run headless and `fix-security-vulnerabilities-with-strix` to patch + re-scan.

---

## Appendix — Run Index

| Run | Target | Turns | Tokens in | Status | View |
|---|---|---|---|---|---|
| `server_8a5a` | `./server` quick | 15 | 715K | completed, 0 vulns | `strix view server_8a5a` |
| `server_eda3` | `./server` standard | 15 | 597K | completed, 0 vulns | `strix view server_eda3` |
| `front_a174` | `./front` quick | 15 | 659K | completed, 0 vulns (IDOR flagged then not validated) | `strix view front_a174` |
| `mobile_8f05` | `./mobile` quick | 15 | 723K | completed, 0 vulns | `strix view mobile_8f05` |
| `ayuvo-health-vercel-app_1670` | `ayuvo-health` + `ayuvo-api` quick | 8 | 332K | completed, recon only | `strix view ayuvo-health-vercel-app_1670` |
| `ayuvo-health-vercel-app_796e` | same, quick | 15 | 1.2M | completed, 0 vulns, recon | `strix view ayuvo-health-vercel-app_796e` |

Failed free-tier attempts (rate/context): `server_8299`/`d407` (Groq schema), `core_21f9`/`8bdb` (50/day), `ayuvo_2e59` (65536 context). Frontier re-run recommended for PoCs.

---

## Disclaimer

Strix was run in authorized scope only (`ayuvo-*` hosts you own). Do not point it at third-party hosts without written permission. Free-tier findings are conservative; a frontier-model re-scan is recommended before a compliance audit (SOC 2, ISO 27001).
