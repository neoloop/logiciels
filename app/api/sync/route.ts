import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth-options";
import { getGraphClient, GraphMessage, escapeODataLiteral, runWithConcurrency } from "@/lib/graph";
import { upsertTrackedEmail, listTrackedEmails, markReplied } from "@/lib/db";

export async function POST() {
  const session = await getServerSession(authOptions);

  if (!session?.accessToken || !session.user?.email) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }
  if (session.error) {
    return NextResponse.json({ error: session.error }, { status: 401 });
  }

  const userEmail = session.user.email;
  const client = getGraphClient(session.accessToken);

  const sentResult = await client
    .api("/me/mailFolders/SentItems/messages")
    .select("id,conversationId,subject,toRecipients,sentDateTime,webLink")
    .orderby("sentDateTime desc")
    .top(50)
    .get();

  const sentMessages: GraphMessage[] = sentResult.value ?? [];
  let syncedCount = 0;

  for (const message of sentMessages) {
    const toRecipients = (message.toRecipients ?? [])
      .map((r) => r.emailAddress?.address)
      .filter((addr): addr is string => Boolean(addr));

    if (toRecipients.length === 0 || !message.sentDateTime) continue;

    upsertTrackedEmail({
      id: message.id,
      userEmail,
      conversationId: message.conversationId,
      subject: message.subject ?? null,
      toRecipients,
      sentAt: message.sentDateTime,
      webLink: message.webLink ?? null,
    });
    syncedCount++;
  }

  const waiting = listTrackedEmails(userEmail).filter((e) => e.status === "waiting");

  let updatedCount = 0;

  await runWithConcurrency(waiting, 5, async (email) => {
    const filter = `conversationId eq '${escapeODataLiteral(email.conversation_id)}'`;
    const inboxResult = await client
      .api("/me/mailFolders/Inbox/messages")
      .filter(filter)
      .select("id,receivedDateTime")
      .orderby("receivedDateTime asc")
      .top(1)
      .get();

    const replies: GraphMessage[] = inboxResult.value ?? [];
    if (replies.length > 0 && replies[0].receivedDateTime) {
      markReplied(email.id, userEmail, replies[0].receivedDateTime);
      updatedCount++;
    }
  });

  return NextResponse.json({ synced: syncedCount, checked: waiting.length, repliesFound: updatedCount });
}
