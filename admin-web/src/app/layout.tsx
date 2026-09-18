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
      <body className="font-sans antialiased bg-[#F8FAFC] text-slate-900 min-h-screen">
        {children}
      </body>
    </html>
  );
}
