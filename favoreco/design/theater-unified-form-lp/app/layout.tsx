import type { Metadata } from "next";
import { Cormorant_Garamond, Noto_Sans_JP } from "next/font/google";
import "./globals.css";

const display = Cormorant_Garamond({
  variable: "--font-display",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

const sans = Noto_Sans_JP({
  variable: "--font-sans",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
});

export const metadata: Metadata = {
  title: "Favoreco | ひとつのページ、5つの入口",
  description: "公演登録から観劇後の記録までをつなぐ、統合編集フォームの完成イメージ。",
  icons: { icon: "/favicon.svg" },
  openGraph: {
    title: "Favoreco | ひとつのページ、5つの入口",
    description: "公演登録から観劇後の記録までをつなぐ、統合編集フォームの完成イメージ。",
    images: [{ url: "/og.png", width: 1736, height: 907 }],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ja">
      <body className={`${display.variable} ${sans.variable}`}>{children}</body>
    </html>
  );
}
