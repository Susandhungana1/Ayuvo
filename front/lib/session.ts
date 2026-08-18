"use client";

/**
 * Login session read from localStorage, exposed as an external store so chrome
 * (navbar, footer) can subscribe without the setState-in-effect pattern the
 * react-hooks v6 rules reject.
 *
 * Written by the auth pages (token + user), read here. Same-tab changes are
 * broadcast with the `localStorageUpdated` CustomEvent; cross-tab changes
 * arrive via the browser's `storage` event. Logout clears the keys and
 * dispatches the same event.
 */

export interface Session {
  token: string | null;
  isDoctor: boolean;
}

const serverSession: Session = { token: null, isDoctor: false };

let cachedRaw = "";
let cachedSession: Session = serverSession;

export function getSessionSnapshot(): Session {
  if (typeof window === "undefined") return serverSession;
  const raw = `${localStorage.getItem("token") ?? ""}|${localStorage.getItem("user") ?? ""}`;
  if (raw !== cachedRaw) {
    cachedRaw = raw;
    let isDoctor = false;
    try {
      const user = JSON.parse(localStorage.getItem("user") || "{}");
      isDoctor = user.role === "DOCTOR";
    } catch {
      /* corrupt user blob — treat as non-doctor */
    }
    cachedSession = { token: localStorage.getItem("token"), isDoctor };
  }
  return cachedSession;
}

export function getSessionServerSnapshot(): Session {
  return serverSession;
}

export function subscribeSession(cb: () => void): () => void {
  window.addEventListener("storage", cb);
  window.addEventListener("localStorageUpdated", cb);
  return () => {
    window.removeEventListener("storage", cb);
    window.removeEventListener("localStorageUpdated", cb);
  };
}