import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "RentTrack Admin Web - Gym, Academy, PG & Tenant Management",
  description: "Comprehensive management app for Gyms, Tuition Centers, Academies, PGs & Rental Properties.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="font-sans antialiased bg-slate-950 text-slate-100 min-h-screen">
        {children}
      </body>
    </html>
  );
}
