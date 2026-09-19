import type { AuthOptions } from "next-auth";
import AzureADProvider from "next-auth/providers/azure-ad";
import { GRAPH_SCOPES, InvalidGrantError, refreshGraphAccessToken } from "@/lib/graph-auth";
import { saveOAuthTokens, deleteOAuthTokens } from "@/lib/db";

async function refreshAccessToken(token: any) {
  try {
    const refreshed = await refreshGraphAccessToken(token.refreshToken);

    if (token.email) {
      saveOAuthTokens(token.email, {
        refreshToken: refreshed.refreshToken,
        accessToken: refreshed.accessToken,
        accessTokenExpires: refreshed.accessTokenExpires,
      });
    }

    return {
      ...token,
      accessToken: refreshed.accessToken,
      accessTokenExpires: refreshed.accessTokenExpires,
      refreshToken: refreshed.refreshToken,
      error: undefined,
    };
  } catch (error) {
    console.error("Échec du rafraîchissement du token", error);
    if (error instanceof InvalidGrantError && token.email) {
      deleteOAuthTokens(token.email);
    }
    return { ...token, error: "RefreshAccessTokenError" as const };
  }
}

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
    async jwt({ token, account }) {
      if (account) {
        const accessTokenExpires = (account.expires_at as number) * 1000;

        if (token.email && account.refresh_token) {
          saveOAuthTokens(token.email, {
            refreshToken: account.refresh_token,
            accessToken: account.access_token ?? null,
            accessTokenExpires,
          });
        }

        return {
          ...token,
          accessToken: account.access_token,
          refreshToken: account.refresh_token,
          accessTokenExpires,
        };
      }

      if (Date.now() < (token.accessTokenExpires as number)) {
        return token;
      }

      return refreshAccessToken(token);
    },
    async session({ session, token }) {
      session.accessToken = token.accessToken as string | undefined;
      session.error = token.error as string | undefined;
      return session;
    },
  },
  session: {
    strategy: "jwt",
  },
};
