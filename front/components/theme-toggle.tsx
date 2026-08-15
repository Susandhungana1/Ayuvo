"use client";

import { useSyncExternalStore } from "react";
import { Moon, Sun } from "lucide-react";

/**
 * Light/dark theme toggle. Persists choice to localStorage and toggles the
 * `.dark` class on <html>. The initial class is applied by an inline script
 * in the root layout to avoid a flash of the wrong theme.
 *
 * The current value is read from the DOM via useSyncExternalStore (server
 * snapshot = light), so there is no mount effect and nothing to flash or
 * remount: hydration renders the server value, then re-renders with the real
 * one. Same-tab changes notify via the `themechange` event; cross-tab via
 * `storage`.
 */
function subscribeTheme(cb: () => void): () => void {
  window.addEventListener("storage", cb);
  window.addEventListener("themechange", cb);
  return () => {
    window.removeEventListener("storage", cb);
    window.removeEventListener("themechange", cb);
  };
}

function getThemeSnapshot(): boolean {
  return document.documentElement.classList.contains("dark");
}

function getThemeServerSnapshot(): boolean {
  return false;
}

export function ThemeToggle() {
  const dark = useSyncExternalStore(subscribeTheme, getThemeSnapshot, getThemeServerSnapshot);

  const toggle = () => {
    const next = !dark;
    document.documentElement.classList.toggle("dark", next);
    try {
      localStorage.setItem("theme", next ? "dark" : "light");
    } catch {
      /* private mode — theme still applies for this session */
    }
    window.dispatchEvent(new Event("themechange"));
  };

  return (
    <button
      onClick={toggle}
      aria-label={dark ? "Switch to light mode" : "Switch to dark mode"}
      title={dark ? "Light mode" : "Dark mode"}
      className="p-2 text-on-surface-variant hover:text-primary transition-colors"
    >
      {dark ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
    </button>
  );
}