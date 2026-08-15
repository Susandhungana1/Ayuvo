import type { Metadata, Viewport } from "next";
import "./globals.css";
import { Figtree, Noto_Sans } from "next/font/google";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";
import { ChatBot } from "@/components/ChatBot";
import { HideOnShare } from "@/components/hide-on-share";
import { PwaRegister } from "@/components/pwa-register";
import { MedicineAlarm } from "@/components/medicine-alarm";
import { I18nProvider } from "@/lib/i18n";
import { ThemeInit } from "@/components/theme-init";

const figtree = Figtree({
  subsets: ["latin"],
  variable: "--font-figtree",
  display: "swap",
});

const notoSans = Noto_Sans({
  subsets: ["latin", "devanagari"],
  variable: "--font-noto-sans",
  display: "swap",
});

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
  themeColor: "#0E7490",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`antialiased ${figtree.variable} ${notoSans.variable}`}
      suppressHydrationWarning
    >
      <body className="min-h-screen flex flex-col font-body">
        <ThemeInit />
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
