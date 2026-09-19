import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth-options";
import { runSyncForUser } from "@/lib/sync-service";

export async function POST() {
  const session = await getServerSession(authOptions);

  if (!session?.accessToken || !session.user?.email) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }
  if (session.error) {
    return NextResponse.json({ error: session.error }, { status: 401 });
  }

  const result = await runSyncForUser(session.user.email, session.accessToken);
  return NextResponse.json(result);
}
