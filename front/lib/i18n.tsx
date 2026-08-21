"use client";

import { createContext, useContext, useEffect, useCallback, useSyncExternalStore } from "react";

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
  "nav.share": { en: "Share", ne: "साझेदारी" },
  "nav.nearby": { en: "Nearby Care", ne: "नजिकैको सेवा" },
  "nav.caretakers": { en: "Caretakers", ne: "हेरचाहकर्ता" },
  "nav.settings": { en: "Settings", ne: "सेटिङ" },
  "nav.availability": { en: "Availability", ne: "उपलब्धता" },
  "nav.more": { en: "More", ne: "थप" },
  "nav.company": { en: "Company", ne: "कम्पनी" },
  "nav.about": { en: "About Us", ne: "हाम्रो बारेमा" },
  "nav.contact": { en: "Contact", ne: "सम्पर्क" },
  "nav.faq": { en: "FAQ", ne: "प्रायः सोधिने प्रश्नहरू" },
  "nav.privacy": { en: "Privacy Policy", ne: "गोपनीयता नीति" },
  "nav.terms": { en: "Terms of Service", ne: "सेवा सर्तहरू" },
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

// Language lives in localStorage; exposed as an external store so changing it
// in one place (the navbar toggle) updates every consumer without effects.
function subscribeLang(cb: () => void): () => void {
  window.addEventListener("storage", cb);
  window.addEventListener("langchange", cb);
  return () => {
    window.removeEventListener("storage", cb);
    window.removeEventListener("langchange", cb);
  };
}

function getLangSnapshot(): Lang {
  try {
    return localStorage.getItem("lang") === "ne" ? "ne" : "en";
  } catch {
    return "en";
  }
}

function getLangServerSnapshot(): Lang {
  return "en";
}

const I18nContext = createContext<I18nContextValue>({
  lang: "en",
  setLang: () => {},
  t: (k) => DICT[k]?.en ?? k,
});

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const lang = useSyncExternalStore(subscribeLang, getLangSnapshot, getLangServerSnapshot);

  // Keep the <html lang> attribute in step with the chosen language. This is
  // an external-system sync only — no setState, so it belongs in an effect.
  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  const setLang = useCallback((l: Lang) => {
    try {
      localStorage.setItem("lang", l);
    } catch {
      /* private mode — apply for this session only */
    }
    document.documentElement.lang = l;
    window.dispatchEvent(new Event("langchange"));
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