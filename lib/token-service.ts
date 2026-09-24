import { getOAuthTokens, saveOAuthTokens, deleteOAuthTokens } from "@/lib/db";
import { refreshGraphAccessToken, InvalidGrantError } from "@/lib/graph-auth";

const ACCESS_TOKEN_EXPIRY_BUFFER_MS = 2 * 60 * 1000;

/**
 * Récupère un token d'accès Graph utilisable pour cet utilisateur, en le rafraîchissant si besoin.
 * Les tokens vivent uniquement côté serveur (SQLite) — jamais dans le cookie de session, pour éviter
 * de dépasser la taille max des en-têtes HTTP (erreur 431) et pour limiter ce qui transite au client.
 */
export async function getUsableAccessToken(userEmail: string): Promise<string | null> {
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
      console.warn(`Token invalide pour ${userEmail}, reconnexion nécessaire.`);
      deleteOAuthTokens(userEmail);
    } else {
      console.error(`Échec du rafraîchissement du token pour ${userEmail}`, error);
    }
    return null;
  }
}
