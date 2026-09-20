import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth-options";
import { untrackEmail } from "@/lib/db";

/** Arrête le suivi d'un mail (le mail redevient disponible dans la liste "mails envoyés récents"). */
export async function DELETE(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await getServerSession(authOptions);
  if (!session?.user?.email) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }

  const { id } = await params;
  untrackEmail(id, session.user.email);
  return NextResponse.json({ ok: true });
}
