"use client";

import { useEffect } from "react";

/**
 * Registers the service worker (PWA offline support + installability).
 * Skipped on localhost (dev mode) and unregisters any stale SW.
 */
export function PwaRegister() {
  useEffect(() => {
    if (typeof window === "undefined" || !("serviceWorker" in navigator)) return;

    // Dev mode: unregister any stale SW and bail.
    if (location.hostname === "localhost" || location.hostname === "127.0.0.1") {
      navigator.serviceWorker.getRegistrations().then((regs) => {
        for (const reg of regs) reg.unregister();
      });
      return;
    }

    const register = () => {
      navigator.serviceWorker
        .register("/sw.js")
        .catch((err) => console.error("SW registration failed:", err));
    };

    if (document.readyState === "complete") {
      register();
    } else {
      window.addEventListener("load", register);
      return () => window.removeEventListener("load", register);
    }
  }, []);

  return null;
}
