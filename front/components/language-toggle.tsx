"use client";

import { useI18n } from "@/lib/i18n";

/** Toggles between English and Nepali. */
export function LanguageToggle() {
  const { lang, setLang } = useI18n();
  return (
    <button
      onClick={() => setLang(lang === "en" ? "ne" : "en")}
      className="px-2 py-1 rounded-sm text-xs font-semibold text-on-surface-variant hover:text-primary border border-outline transition-colors"
      title={lang === "en" ? "नेपालीमा बदल्नुहोस्" : "Switch to English"}
      aria-label="Toggle language"
    >
      {lang === "en" ? "ने" : "EN"}
    </button>
  );
}