import { getGraphClient, GraphMessage, escapeODataLiteral, runWithConcurrency } from "@/lib/graph";
import { upsertTrackedEmail, listTrackedEmails, markReplied, touchLastSyncedAt } from "@/lib/db";

export interface SyncResult {
  synced: number;
  checked: number;
  repliesFound: number;
}

/** Fetches recently sent mail, records it, and checks the Inbox for replies to anything still "waiting". */
export async function runSyncForUser(userEmail: string, accessToken: string): Promise<SyncResult> {
  const client = getGraphClient(accessToken);

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

  touchLastSyncedAt(userEmail, new Date().toISOString());

  return { synced: syncedCount, checked: waiting.length, repliesFound: updatedCount };
}
