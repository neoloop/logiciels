import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth-options";
import { getUsableAccessToken } from "@/lib/token-service";
import { checkRepliesForTrackedEmails } from "@/lib/sync-service";

/** Vérifie les réponses pour les mails déjà suivis. N'ajoute rien au suivi (voir /api/emails/track). */
export async function POST() {
  const session = await getServerSession(authOptions);
  if (!session?.user?.email) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }

  const accessToken = await getUsableAccessToken(session.user.email);
  if (!accessToken) {
    return NextResponse.json({ error: "Session Microsoft expirée, reconnecte-toi." }, { status: 401 });
  }

  const result = await checkRepliesForTrackedEmails(session.user.email, accessToken);
  return NextResponse.json(result);
}
