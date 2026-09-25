import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth-options";
import { getUsableAccessToken } from "@/lib/token-service";
import { fetchRecentSentMessages } from "@/lib/sync-service";
import { listTrackedEmails } from "@/lib/db";

/** Liste les mails envoyés récemment (Graph) pour que l'utilisateur choisisse lesquels suivre. */
export async function GET() {
  const session = await getServerSession(authOptions);
  if (!session?.user?.email) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }

  const accessToken = await getUsableAccessToken(session.user.email);
  if (!accessToken) {
    return NextResponse.json({ error: "Session Microsoft expirée, reconnecte-toi." }, { status: 401 });
  }

  const [messages, tracked] = await Promise.all([
    fetchRecentSentMessages(accessToken),
    Promise.resolve(listTrackedEmails(session.user.email)),
  ]);

  const trackedIds = new Set(tracked.map((e) => e.id));
  const candidates = messages.filter((m) => !trackedIds.has(m.id));

  return NextResponse.json({ candidates });
}
