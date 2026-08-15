"use client";

import { useEffect } from "react";

export function ThemeInit() {
  useEffect(() => {
    try {
      const t = localStorage.getItem("theme");
      const m = window.matchMedia("(prefers-color-scheme: dark)").matches;
      if (t === "dark" || (!t && m)) {
        document.documentElement.classList.add("dark");
      }
    } catch {}
  }, []);

  return null;
}
