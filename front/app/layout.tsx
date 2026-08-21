import type { Metadata, Viewport } from "next";
import "./globals.css";
import { Figtree, Noto_Sans } from "next/font/google";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";
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
  description: "Securely manage, track, and share your medical records. Your personal digital health store for vitals, medicines, reports, and more.",
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
  openGraph: {
    title: "MediStore - Your Personal Digital Health Store",
    description: "Securely manage, track, and share your medical records.",
    url: "https://medistore-health.vercel.app",
    siteName: "MediStore",
    type: "website",
    locale: "en_US",
    images: [
      {
        url: "/icon-512.png",
        width: 512,
        height: 512,
        alt: "MediStore",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "MediStore - Your Personal Digital Health Store",
    description: "Securely manage, track, and share your medical records.",
    images: ["/icon-512.png"],
  },
};

export const viewport: Viewport = {
  themeColor: "#0E7490",
};

// CSP nonces are per-request: Next.js stamps them onto inline RSC payload
// scripts during SSR by reading the CSP request header. Statically-prerendered
// pages are built without any request headers, so they would ship scripts
// with no nonce and our strict script-src policy would block them.
export const dynamic = "force-dynamic";

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
          <PwaRegister />
          <MedicineAlarm />
        </I18nProvider>
        {/* Structured data — Organization + WebSite so search engines can
            attribute the site correctly. Rendered server-side. */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              "@context": "https://schema.org",
              "@graph": [
                {
                  "@type": "Organization",
                  "@id": "https://medistore-health.vercel.app/#organization",
                  name: "MediStore",
                  url: "https://medistore-health.vercel.app",
                  logo: "https://medistore-health.vercel.app/icon-512.png",
                  email: "quorlytechnologies@gmail.com",
                  description: "Personal digital health store — securely manage, track, and share your medical records.",
                },
                {
                  "@type": "WebSite",
                  "@id": "https://medistore-health.vercel.app/#website",
                  url: "https://medistore-health.vercel.app",
                  name: "MediStore",
                  publisher: { "@id": "https://medistore-health.vercel.app/#organization" },
                },
              ],
            }),
          }}
        />
      </body>
    </html>
  );
}
