import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth-options";
import { listTrackedEmails, getFollowUpDelayDays } from "@/lib/db";
import { computeDisplayStatus } from "@/lib/status";

export async function GET() {
  const session = await getServerSession(authOptions);
  if (!session?.user?.email) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }

  const userEmail = session.user.email;
  const delayDays = getFollowUpDelayDays(userEmail);
  const emails = listTrackedEmails(userEmail).map((email) => ({
    ...email,
    to_recipients: JSON.parse(email.to_recipients) as string[],
    display_status: computeDisplayStatus(email, delayDays),
  }));

  return NextResponse.json({ emails, delayDays });
}
