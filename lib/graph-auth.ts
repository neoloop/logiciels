export const GRAPH_SCOPES = "openid profile email offline_access Mail.Read Mail.ReadWrite";

export interface RefreshedGraphTokens {
  accessToken: string;
  refreshToken: string;
  accessTokenExpires: number;
}

/** Thrown when the refresh token itself is no longer valid (revoked, password change, ...). */
export class InvalidGrantError extends Error {}

export async function refreshGraphAccessToken(refreshToken: string): Promise<RefreshedGraphTokens> {
  const tenantId = process.env.AZURE_AD_TENANT_ID;
  const url = `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`;

  const body = new URLSearchParams({
    client_id: process.env.AZURE_AD_CLIENT_ID!,
    client_secret: process.env.AZURE_AD_CLIENT_SECRET!,
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    scope: GRAPH_SCOPES,
  });

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  const payload = await response.json();

  if (!response.ok) {
    if (payload?.error === "invalid_grant") {
      throw new InvalidGrantError(payload.error_description ?? "invalid_grant");
    }
    throw new Error(payload?.error_description ?? "Échec du rafraîchissement du token Graph");
  }

  return {
    accessToken: payload.access_token,
    refreshToken: payload.refresh_token ?? refreshToken,
    accessTokenExpires: Date.now() + payload.expires_in * 1000,
  };
}
