import {
  listUserEmailsWithSyncEnabled,
  getSettings,
  getOAuthTokens,
  saveOAuthTokens,
  deleteOAuthTokens,
} from "@/lib/db";
import { refreshGraphAccessToken, InvalidGrantError } from "@/lib/graph-auth";
import { runSyncForUser } from "@/lib/sync-service";

const TICK_MS = 5 * 60 * 1000; // fréquence de vérification ; chaque utilisateur garde son propre intervalle
const ACCESS_TOKEN_EXPIRY_BUFFER_MS = 2 * 60 * 1000;

async function getUsableAccessToken(userEmail: string): Promise<string | null> {
  const tokens = getOAuthTokens(userEmail);
  if (!tokens) return null;

  const stillValid =
    tokens.accessToken &&
    tokens.accessTokenExpires &&
    tokens.accessTokenExpires - ACCESS_TOKEN_EXPIRY_BUFFER_MS > Date.now();

  if (stillValid) {
    return tokens.accessToken!;
  }

  try {
    const refreshed = await refreshGraphAccessToken(tokens.refreshToken);
    saveOAuthTokens(userEmail, {
      refreshToken: refreshed.refreshToken,
      accessToken: refreshed.accessToken,
      accessTokenExpires: refreshed.accessTokenExpires,
    });
    return refreshed.accessToken;
  } catch (error) {
    if (error instanceof InvalidGrantError) {
      console.warn(`Sync en arrière-plan: token invalide pour ${userEmail}, reconnexion nécessaire.`);
      deleteOAuthTokens(userEmail);
    } else {
      console.error(`Sync en arrière-plan: échec du rafraîchissement du token pour ${userEmail}`, error);
    }
    return null;
  }
}

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

      const result = await runSyncForUser(userEmail, accessToken);
      console.log(
        `Sync en arrière-plan pour ${userEmail}: ${result.synced} mail(s) importé(s), ${result.repliesFound} réponse(s) détectée(s).`
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
