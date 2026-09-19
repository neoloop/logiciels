import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth-options";
import { getGraphClient } from "@/lib/graph";
import { getTrackedEmail, recordFollowUp } from "@/lib/db";

const DEFAULT_COMMENT =
  "Bonjour,\n\nJe me permets de revenir vers vous : je n'ai pas eu de retour concernant ce message. " +
  "N'hésitez pas à me faire savoir si vous avez besoin de plus d'informations de ma part.\n\nBien cordialement,";

/**
 * Crée un BROUILLON de relance dans la boîte Outlook de l'utilisateur (via createReply) et
 * s'arrête là : rien n'est envoyé automatiquement. L'utilisateur relit et envoie lui-même.
 */
export async function POST(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await getServerSession(authOptions);
  if (!session?.accessToken || !session.user?.email) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }

  const { id } = await params;
  const userEmail = session.user.email;
  const tracked = getTrackedEmail(id, userEmail);
  if (!tracked) {
    return NextResponse.json({ error: "Email inconnu" }, { status: 404 });
  }

  let comment = DEFAULT_COMMENT;
  try {
    const body = await req.json();
    if (typeof body?.comment === "string" && body.comment.trim()) {
      comment = body.comment;
    }
  } catch {
    // pas de corps JSON fourni, on garde le message par défaut
  }

  const client = getGraphClient(session.accessToken);

  const draft = await client.api(`/me/messages/${id}/createReply`).post({ comment });

  recordFollowUp(id, userEmail, new Date().toISOString());

  return NextResponse.json({
    draftId: draft.id,
    webLink: draft.webLink,
  });
}
