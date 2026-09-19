import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth-options";
import { getFollowUpDelayDays, setFollowUpDelayDays } from "@/lib/db";

export async function GET() {
  const session = await getServerSession(authOptions);
  if (!session?.user?.email) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }

  return NextResponse.json({ delayDays: getFollowUpDelayDays(session.user.email) });
}

export async function POST(req: Request) {
  const session = await getServerSession(authOptions);
  if (!session?.user?.email) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }

  const { delayDays } = await req.json();
  const parsed = Number(delayDays);
  if (!Number.isFinite(parsed) || parsed < 1 || parsed > 60) {
    return NextResponse.json({ error: "Valeur invalide (1 à 60 jours)" }, { status: 400 });
  }

  setFollowUpDelayDays(session.user.email, parsed);
  return NextResponse.json({ ok: true, delayDays: parsed });
}
