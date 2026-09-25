import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth-options";
import { getSettings, setFollowUpDelayDays, setSyncIntervalMinutes } from "@/lib/db";

const ALLOWED_SYNC_INTERVALS = [0, 15, 30, 60, 120, 240];

export async function GET() {
  const session = await getServerSession(authOptions);
  if (!session?.user?.email) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }

  return NextResponse.json(getSettings(session.user.email));
}

export async function POST(req: Request) {
  const session = await getServerSession(authOptions);
  if (!session?.user?.email) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }

  const userEmail = session.user.email;
  const { delayDays, syncIntervalMinutes } = await req.json();

  if (delayDays !== undefined) {
    const parsed = Number(delayDays);
    if (!Number.isFinite(parsed) || parsed < 1 || parsed > 60) {
      return NextResponse.json({ error: "Le délai de relance doit être entre 1 et 60 jours." }, { status: 400 });
    }
    setFollowUpDelayDays(userEmail, parsed);
  }

  if (syncIntervalMinutes !== undefined) {
    const parsed = Number(syncIntervalMinutes);
    if (!ALLOWED_SYNC_INTERVALS.includes(parsed)) {
      return NextResponse.json({ error: "Intervalle de synchronisation invalide." }, { status: 400 });
    }
    setSyncIntervalMinutes(userEmail, parsed);
  }

  return NextResponse.json(getSettings(userEmail));
}
