"use client";

import { useSession, signIn } from "next-auth/react";
import Dashboard from "@/components/Dashboard";

export default function Home() {
  const { data: session, status } = useSession();

  if (status === "loading") {
    return (
      <div className="flex min-h-screen items-center justify-center text-sm text-slate-500">
        Chargement...
      </div>
    );
  }

  if (!session) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-4 px-4 text-center">
        <h1 className="text-2xl font-semibold">Suivi de mails & relances</h1>
        <p className="max-w-md text-sm text-slate-500">
          Connecte-toi avec ton compte Microsoft 365 pour suivre tes mails envoyés et savoir quand relancer.
        </p>
        <button
          onClick={() => signIn("azure-ad")}
          className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500"
        >
          Se connecter avec Microsoft
        </button>
      </div>
    );
  }

  return <Dashboard userName={session.user?.name ?? session.user?.email ?? "utilisateur"} />;
}
