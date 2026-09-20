import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth-options";
import { fetchSentMessageById } from "@/lib/sync-service";
import { upsertTrackedEmail } from "@/lib/db";

/** Ajoute un mail choisi par l'utilisateur au suivi. */
export async function POST(req: Request) {
  const session = await getServerSession(authOptions);
  if (!session?.accessToken || !session.user?.email) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }
  if (session.error) {
    return NextResponse.json({ error: session.error }, { status: 401 });
  }

  const { id } = await req.json().catch(() => ({}));
  if (typeof id !== "string" || !id) {
    return NextResponse.json({ error: "Identifiant de mail manquant" }, { status: 400 });
  }

  const message = await fetchSentMessageById(session.accessToken, id);
  if (!message) {
    return NextResponse.json({ error: "Mail introuvable ou sans destinataire" }, { status: 404 });
  }

  upsertTrackedEmail({
    id: message.id,
    userEmail: session.user.email,
    conversationId: message.conversationId,
    subject: message.subject,
    toRecipients: message.toRecipients,
    sentAt: message.sentAt,
    webLink: message.webLink,
  });

  return NextResponse.json({ ok: true });
}
