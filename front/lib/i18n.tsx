"use client";

import { createContext, useContext, useEffect, useState, useCallback } from "react";

export type Lang = "en" | "ne";

// Translation dictionary. Keys are stable ids; add more as pages are localized.
const DICT: Record<string, { en: string; ne: string }> = {
  // Navigation
  "nav.home": { en: "Home", ne: "गृहपृष्ठ" },
  "nav.dashboard": { en: "Dashboard", ne: "ड्यासबोर्ड" },
  "nav.reports": { en: "Reports", ne: "रिपोर्टहरू" },
  "nav.medicines": { en: "Medicines", ne: "औषधिहरू" },
  "nav.vitals": { en: "Vitals", ne: "स्वास्थ्य नाप" },
  "nav.appointments": { en: "Appointments", ne: "अपोइन्टमेन्ट" },
  "nav.emergency": { en: "Emergency ID", ne: "आपतकालीन आईडी" },
  "nav.timeline": { en: "Timeline", ne: "समयरेखा" },
  "nav.share": { en: "Share", ne: "साझेदारी" },
  "nav.nearby": { en: "Nearby Care", ne: "नजिकैको सेवा" },
  "nav.family": { en: "Family", ne: "परिवार" },
  "nav.availability": { en: "Availability", ne: "उपलब्धता" },
  "nav.more": { en: "More", ne: "थप" },
  "nav.login": { en: "Log in", ne: "लग इन" },
  "nav.logout": { en: "Logout", ne: "लगआउट" },
  "nav.getStarted": { en: "Get Started", ne: "सुरु गर्नुहोस्" },
  "nav.search": { en: "Search reports, medicines...", ne: "खोज्नुहोस्..." },
};

interface I18nContextValue {
  lang: Lang;
  setLang: (l: Lang) => void;
  t: (key: string) => string;
}

const I18nContext = createContext<I18nContextValue>({
  lang: "en",
  setLang: () => {},
  t: (k) => DICT[k]?.en ?? k,
});

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLangState] = useState<Lang>("en");

  useEffect(() => {
    try {
      const saved = localStorage.getItem("lang") as Lang | null;
      if (saved === "en" || saved === "ne") {
        setLangState(saved);
        document.documentElement.lang = saved;
      }
    } catch {}
  }, []);

  const setLang = useCallback((l: Lang) => {
    setLangState(l);
    try {
      localStorage.setItem("lang", l);
      document.documentElement.lang = l;
    } catch {}
  }, []);

  const t = useCallback(
    (key: string) => DICT[key]?.[lang] ?? DICT[key]?.en ?? key,
    [lang]
  );

  return (
    <I18nContext.Provider value={{ lang, setLang, t }}>
      {children}
    </I18nContext.Provider>
  );
}

export function useI18n() {
  return useContext(I18nContext);
}
