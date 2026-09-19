"use client";

import { useCallback, useEffect, useState } from "react";
import { signOut } from "next-auth/react";
import StatusBadge from "@/components/StatusBadge";
import type { DisplayStatus } from "@/lib/status";

interface EmailRow {
  id: string;
  subject: string | null;
  to_recipients: string[];
  sent_at: string;
  display_status: DisplayStatus;
  follow_up_count: number;
  last_follow_up_at: string | null;
  web_link: string | null;
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleString("fr-FR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

const SYNC_INTERVAL_OPTIONS = [
  { value: 0, label: "Désactivée (manuelle uniquement)" },
  { value: 15, label: "Toutes les 15 min" },
  { value: 30, label: "Toutes les 30 min" },
  { value: 60, label: "Toutes les heures" },
  { value: 120, label: "Toutes les 2 heures" },
  { value: 240, label: "Toutes les 4 heures" },
];

// Rafraîchit juste la liste affichée (sans appeler Outlook) pour montrer les
// résultats de la synchronisation automatique en arrière-plan.
const LIST_REFRESH_MS = 60 * 1000;

export default function Dashboard({ userName }: { userName: string }) {
  const [emails, setEmails] = useState<EmailRow[]>([]);
  const [delayDays, setDelayDays] = useState(3);
  const [delayInput, setDelayInput] = useState("3");
  const [syncIntervalMinutes, setSyncIntervalMinutes] = useState(15);
  const [lastSyncedAt, setLastSyncedAt] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);
  const [followUpBusyId, setFollowUpBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<"all" | DisplayStatus>("all");

  const loadEmails = useCallback(async () => {
    const res = await fetch("/api/emails");
    if (!res.ok) {
      setError("Impossible de charger les emails suivis.");
      return;
    }
    const data = await res.json();
    setEmails(data.emails);
    setDelayDays(data.followUpDelayDays);
    setDelayInput(String(data.followUpDelayDays));
    setSyncIntervalMinutes(data.syncIntervalMinutes);
    setLastSyncedAt(data.lastSyncedAt);
    setError(null);
  }, []);

  useEffect(() => {
    loadEmails().finally(() => setLoading(false));
  }, [loadEmails]);

  useEffect(() => {
    const id = setInterval(() => {
      loadEmails();
    }, LIST_REFRESH_MS);
    return () => clearInterval(id);
  }, [loadEmails]);

  const handleSync = async () => {
    setSyncing(true);
    setError(null);
    try {
      const res = await fetch("/api/sync", { method: "POST" });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.error ?? "Échec de la synchronisation");
      }
      await loadEmails();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Erreur inconnue");
    } finally {
      setSyncing(false);
    }
  };

  const handleDismiss = async (id: string) => {
    setEmails((prev) => prev.map((e) => (e.id === id ? { ...e, display_status: "dismissed" } : e)));
    await fetch(`/api/emails/${id}/dismiss`, { method: "POST" });
    await loadEmails();
  };

  const handleFollowUp = async (id: string) => {
    setFollowUpBusyId(id);
    setError(null);
    try {
      const res = await fetch(`/api/emails/${id}/follow-up`, { method: "POST" });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.error ?? "Échec de la création du brouillon");
      }
      const data = await res.json();
      await loadEmails();
      if (data.webLink) {
        window.open(data.webLink, "_blank", "noopener,noreferrer");
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Erreur inconnue");
    } finally {
      setFollowUpBusyId(null);
    }
  };

  const handleDelaySave = async () => {
    const value = Number(delayInput);
    if (!Number.isFinite(value) || value < 1 || value > 60) {
      setError("Le délai doit être entre 1 et 60 jours.");
      return;
    }
    const res = await fetch("/api/settings", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ delayDays: value }),
    });
    if (res.ok) {
      setDelayDays(value);
      await loadEmails();
    }
  };

  const handleSyncIntervalChange = async (value: number) => {
    setSyncIntervalMinutes(value);
    const res = await fetch("/api/settings", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ syncIntervalMinutes: value }),
    });
    if (!res.ok) {
      setError("Impossible d'enregistrer l'intervalle de synchronisation.");
      await loadEmails();
    }
  };

  const visibleEmails = emails.filter((e) => filter === "all" || e.display_status === filter);
  const needsFollowUpCount = emails.filter((e) => e.display_status === "needs_follow_up").length;

  return (
    <div className="mx-auto max-w-5xl px-4 py-8">
      <header className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Suivi de mails & relances</h1>
          <p className="text-sm text-slate-500">Connecté en tant que {userName}</p>
        </div>
        <button
          onClick={() => signOut()}
          className="text-sm text-slate-500 underline hover:text-slate-700"
        >
          Se déconnecter
        </button>
      </header>

      <div className="mb-6 flex flex-wrap items-center gap-3 rounded-lg border border-slate-200 bg-white p-4">
        <button
          onClick={handleSync}
          disabled={syncing}
          className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
        >
          {syncing ? "Synchronisation..." : "Synchroniser avec Outlook"}
        </button>

        <div className="flex items-center gap-2 text-sm text-slate-600">
          <label htmlFor="delay">Relancer après</label>
          <input
            id="delay"
            type="number"
            min={1}
            max={60}
            value={delayInput}
            onChange={(e) => setDelayInput(e.target.value)}
            className="w-16 rounded border border-slate-300 px-2 py-1"
          />
          <span>jours sans réponse</span>
          {delayInput !== String(delayDays) && (
            <button
              onClick={handleDelaySave}
              className="rounded bg-slate-800 px-2 py-1 text-xs text-white hover:bg-slate-700"
            >
              Enregistrer
            </button>
          )}
        </div>

        <div className="flex items-center gap-2 text-sm text-slate-600">
          <label htmlFor="sync-interval">Synchro automatique</label>
          <select
            id="sync-interval"
            value={syncIntervalMinutes}
            onChange={(e) => handleSyncIntervalChange(Number(e.target.value))}
            className="rounded border border-slate-300 px-2 py-1"
          >
            {SYNC_INTERVAL_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        </div>

        {lastSyncedAt && (
          <span className="text-xs text-slate-400">Dernière synchro : {formatDate(lastSyncedAt)}</span>
        )}

        {needsFollowUpCount > 0 && (
          <span className="ml-auto rounded-full bg-amber-100 px-3 py-1 text-sm font-medium text-amber-800">
            {needsFollowUpCount} mail{needsFollowUpCount > 1 ? "s" : ""} à relancer
          </span>
        )}
      </div>

      {error && (
        <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-4 py-2 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="mb-4 flex gap-2 text-sm">
        {(["all", "needs_follow_up", "waiting", "replied", "dismissed"] as const).map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`rounded-full px-3 py-1 ${
              filter === f ? "bg-slate-800 text-white" : "bg-slate-100 text-slate-600 hover:bg-slate-200"
            }`}
          >
            {f === "all" && "Tous"}
            {f === "needs_follow_up" && "À relancer"}
            {f === "waiting" && "En attente"}
            {f === "replied" && "Répondu"}
            {f === "dismissed" && "Ignorés"}
          </button>
        ))}
      </div>

      {loading ? (
        <p className="text-sm text-slate-500">Chargement...</p>
      ) : visibleEmails.length === 0 ? (
        <p className="text-sm text-slate-500">
          Aucun email à afficher. Clique sur « Synchroniser avec Outlook » pour importer tes mails envoyés.
        </p>
      ) : (
        <div className="overflow-hidden rounded-lg border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-50 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">Sujet</th>
                <th className="px-4 py-3">Destinataires</th>
                <th className="px-4 py-3">Envoyé le</th>
                <th className="px-4 py-3">Statut</th>
                <th className="px-4 py-3">Relances</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {visibleEmails.map((email) => (
                <tr key={email.id}>
                  <td className="max-w-xs truncate px-4 py-3 font-medium">
                    {email.web_link ? (
                      <a
                        href={email.web_link}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="hover:underline"
                      >
                        {email.subject || "(sans objet)"}
                      </a>
                    ) : (
                      email.subject || "(sans objet)"
                    )}
                  </td>
                  <td className="max-w-xs truncate px-4 py-3 text-slate-500">
                    {email.to_recipients.join(", ")}
                  </td>
                  <td className="whitespace-nowrap px-4 py-3 text-slate-500">
                    {formatDate(email.sent_at)}
                  </td>
                  <td className="px-4 py-3">
                    <StatusBadge status={email.display_status} />
                  </td>
                  <td className="px-4 py-3 text-slate-500">
                    {email.follow_up_count > 0
                      ? `${email.follow_up_count} (dernière: ${formatDate(email.last_follow_up_at!)})`
                      : "—"}
                  </td>
                  <td className="whitespace-nowrap px-4 py-3 text-right">
                    {email.display_status !== "replied" && email.display_status !== "dismissed" && (
                      <div className="flex justify-end gap-2">
                        <button
                          onClick={() => handleFollowUp(email.id)}
                          disabled={followUpBusyId === email.id}
                          className="rounded bg-amber-500 px-2 py-1 text-xs font-medium text-white hover:bg-amber-400 disabled:opacity-50"
                        >
                          {followUpBusyId === email.id ? "..." : "Relancer"}
                        </button>
                        <button
                          onClick={() => handleDismiss(email.id)}
                          className="rounded bg-slate-100 px-2 py-1 text-xs text-slate-600 hover:bg-slate-200"
                        >
                          Ignorer
                        </button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <p className="mt-6 text-xs text-slate-400">
        « Relancer » crée un brouillon de réponse dans Outlook et l&apos;ouvre pour relecture — rien n&apos;est
        envoyé automatiquement. La synchro automatique tourne côté serveur tant que l&apos;application est
        lancée (<code>npm run dev</code>/<code>npm start</code>), même si cette page est fermée.
      </p>
    </div>
  );
}
