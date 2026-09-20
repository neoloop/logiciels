import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth-options";
import { checkRepliesForTrackedEmails } from "@/lib/sync-service";

/** Vérifie les réponses pour les mails déjà suivis. N'ajoute rien au suivi (voir /api/emails/track). */
export async function POST() {
  const session = await getServerSession(authOptions);

  if (!session?.accessToken || !session.user?.email) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }
  if (session.error) {
    return NextResponse.json({ error: session.error }, { status: 401 });
  }

  const result = await checkRepliesForTrackedEmails(session.user.email, session.accessToken);
  return NextResponse.json(result);
}
