import type { AuthOptions } from "next-auth";
import AzureADProvider from "next-auth/providers/azure-ad";
import { GRAPH_SCOPES } from "@/lib/graph-auth";
import { saveOAuthTokens } from "@/lib/db";

export const authOptions: AuthOptions = {
  providers: [
    AzureADProvider({
      clientId: process.env.AZURE_AD_CLIENT_ID!,
      clientSecret: process.env.AZURE_AD_CLIENT_SECRET!,
      tenantId: process.env.AZURE_AD_TENANT_ID,
      authorization: { params: { scope: GRAPH_SCOPES } },
    }),
  ],
  callbacks: {
    // Ne garde dans le token/cookie de session que l'identité (email, nom) — jamais les tokens Graph,
    // pour éviter de dépasser la taille max des en-têtes HTTP et limiter ce qui transite au client.
    // Les tokens Graph eux-mêmes vivent uniquement en base (voir lib/token-service.ts).
    async jwt({ token, account }) {
      if (account && token.email && account.refresh_token) {
        saveOAuthTokens(token.email, {
          refreshToken: account.refresh_token,
          accessToken: account.access_token ?? null,
          accessTokenExpires: (account.expires_at as number) * 1000,
        });
      }
      return token;
    },
  },
  session: {
    strategy: "jwt",
  },
};
