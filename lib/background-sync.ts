import { listUserEmailsWithSyncEnabled, getSettings } from "@/lib/db";
import { getUsableAccessToken } from "@/lib/token-service";
import { checkRepliesForTrackedEmails } from "@/lib/sync-service";

const TICK_MS = 5 * 60 * 1000; // fréquence de vérification ; chaque utilisateur garde son propre intervalle

async function runBackgroundSyncCycle() {
  const userEmails = listUserEmailsWithSyncEnabled();

  for (const userEmail of userEmails) {
    try {
      const settings = getSettings(userEmail);
      if (settings.syncIntervalMinutes <= 0) continue;

      const dueAt = settings.lastSyncedAt
        ? new Date(settings.lastSyncedAt).getTime() + settings.syncIntervalMinutes * 60 * 1000
        : 0;
      if (Date.now() < dueAt) continue;

      const accessToken = await getUsableAccessToken(userEmail);
      if (!accessToken) continue;

      const result = await checkRepliesForTrackedEmails(userEmail, accessToken);
      console.log(
        `Sync en arrière-plan pour ${userEmail}: ${result.checked} mail(s) suivi(s) vérifié(s), ${result.repliesFound} réponse(s) détectée(s).`
      );
    } catch (error) {
      console.error(`Sync en arrière-plan: erreur pour ${userEmail}`, error);
    }
  }
}

declare global {
  // eslint-disable-next-line no-var
  var __mailTrackerBackgroundSyncStarted: boolean | undefined;
}

export function startBackgroundSync() {
  if (globalThis.__mailTrackerBackgroundSyncStarted) return;
  globalThis.__mailTrackerBackgroundSyncStarted = true;

  console.log("Sync en arrière-plan: démarrage (vérification toutes les 5 minutes).");

  const tick = () => {
    runBackgroundSyncCycle().catch((error) =>
      console.error("Sync en arrière-plan: cycle échoué", error)
    );
  };

  setTimeout(tick, 30 * 1000);
  setInterval(tick, TICK_MS);
}
