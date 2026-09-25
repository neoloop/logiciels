import { getGraphClient, GraphMessage, escapeODataLiteral, runWithConcurrency } from "@/lib/graph";
import { listTrackedEmails, markReplied, touchLastSyncedAt } from "@/lib/db";

export interface SentMessageSummary {
  id: string;
  conversationId: string;
  subject: string | null;
  toRecipients: string[];
  sentAt: string;
  webLink: string | null;
}

function toSummary(message: GraphMessage): SentMessageSummary | null {
  const toRecipients = (message.toRecipients ?? [])
    .map((r) => r.emailAddress?.address)
    .filter((addr): addr is string => Boolean(addr));

  if (toRecipients.length === 0 || !message.sentDateTime) return null;

  return {
    id: message.id,
    conversationId: message.conversationId,
    subject: message.subject ?? null,
    toRecipients,
    sentAt: message.sentDateTime,
    webLink: message.webLink ?? null,
  };
}

/** Mails envoyés récemment, pour laisser l'utilisateur choisir lesquels suivre. Ne touche pas la base. */
export async function fetchRecentSentMessages(accessToken: string): Promise<SentMessageSummary[]> {
  const client = getGraphClient(accessToken);

  const sentResult = await client
    .api("/me/mailFolders/SentItems/messages")
    .select("id,conversationId,subject,toRecipients,sentDateTime,webLink")
    .orderby("sentDateTime desc")
    .top(50)
    .get();

  const sentMessages: GraphMessage[] = sentResult.value ?? [];
  return sentMessages.map(toSummary).filter((m): m is SentMessageSummary => m !== null);
}

/** Récupère un mail précis depuis Graph pour l'ajouter au suivi (choix explicite de l'utilisateur). */
export async function fetchSentMessageById(
  accessToken: string,
  messageId: string
): Promise<SentMessageSummary | null> {
  const client = getGraphClient(accessToken);
  const message: GraphMessage = await client
    .api(`/me/messages/${messageId}`)
    .select("id,conversationId,subject,toRecipients,sentDateTime,webLink")
    .get();

  return toSummary(message);
}

export interface ReplyCheckResult {
  checked: number;
  repliesFound: number;
}

/** Vérifie, pour chaque mail suivi encore "en attente", si une réponse est arrivée dans Inbox. */
export async function checkRepliesForTrackedEmails(
  userEmail: string,
  accessToken: string
): Promise<ReplyCheckResult> {
  const client = getGraphClient(accessToken);
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

  return { checked: waiting.length, repliesFound: updatedCount };
}
