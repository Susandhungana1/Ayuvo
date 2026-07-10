import type { Metadata, Viewport } from "next";
import "./globals.css";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";
import { ChatBot } from "@/components/ChatBot";
import { HideOnShare } from "@/components/hide-on-share";
import { PwaRegister } from "@/components/pwa-register";
import { MedicineAlarm } from "@/components/medicine-alarm";
import { I18nProvider } from "@/lib/i18n";

export const metadata: Metadata = {
  title: "MediStore - Your Personal Digital Health Store",
  description: "Securely manage, track, and share your medical records.",
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "MediStore",
  },
  icons: {
    icon: "/icon-32.png",
    apple: "/apple-touch-icon.png",
  },
};

export const viewport: Viewport = {
  themeColor: "#2563EB",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="antialiased" suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var t=localStorage.getItem('theme');var m=window.matchMedia('(prefers-color-scheme: dark)').matches;if(t==='dark'||(!t&&m)){document.documentElement.classList.add('dark');}}catch(e){}})();`,
          }}
        />
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){if(location.hostname==='localhost'||location.hostname==='127.0.0.1'){try{if(navigator.serviceWorker){navigator.serviceWorker.getRegistrations().then(function(r){r.forEach(function(s){s.unregister()})})}if(window.caches&&caches.keys){caches.keys().then(function(keys){keys.forEach(function(k){caches.delete(k)})})}}catch(e){}}})();`,
          }}
        />
      </head>
      <body className="min-h-screen flex flex-col font-sans">
        <I18nProvider>
          <HideOnShare><Navbar /></HideOnShare>
          <main className="flex-grow">
            {children}
          </main>
          <HideOnShare><Footer /></HideOnShare>
          <HideOnShare><ChatBot /></HideOnShare>
          <PwaRegister />
          <MedicineAlarm />
        </I18nProvider>
      </body>
    </html>
  );
}
