import Database from "better-sqlite3";
import path from "path";
import fs from "fs";

const DATA_DIR = path.join(process.cwd(), "data");
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

const db = new Database(path.join(DATA_DIR, "tracker.db"));
db.pragma("journal_mode = WAL");

db.exec(`
  CREATE TABLE IF NOT EXISTS tracked_emails (
    id TEXT NOT NULL,
    user_email TEXT NOT NULL,
    conversation_id TEXT NOT NULL,
    subject TEXT,
    to_recipients TEXT NOT NULL DEFAULT '[]',
    sent_at TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'waiting',
    replied_at TEXT,
    last_follow_up_at TEXT,
    follow_up_count INTEGER NOT NULL DEFAULT 0,
    web_link TEXT,
    PRIMARY KEY (id, user_email)
  );

  CREATE TABLE IF NOT EXISTS settings (
    user_email TEXT PRIMARY KEY,
    follow_up_delay_days INTEGER NOT NULL DEFAULT 3
  );
`);

export type EmailStatus = "waiting" | "replied" | "dismissed";

export interface TrackedEmail {
  id: string;
  user_email: string;
  conversation_id: string;
  subject: string | null;
  to_recipients: string;
  sent_at: string;
  status: EmailStatus;
  replied_at: string | null;
  last_follow_up_at: string | null;
  follow_up_count: number;
  web_link: string | null;
}

const DEFAULT_DELAY_DAYS = Number(process.env.DEFAULT_FOLLOW_UP_DELAY_DAYS ?? 3);

export function upsertTrackedEmail(email: {
  id: string;
  userEmail: string;
  conversationId: string;
  subject: string | null;
  toRecipients: string[];
  sentAt: string;
  webLink: string | null;
}) {
  const stmt = db.prepare(`
    INSERT INTO tracked_emails (id, user_email, conversation_id, subject, to_recipients, sent_at, web_link)
    VALUES (@id, @userEmail, @conversationId, @subject, @toRecipients, @sentAt, @webLink)
    ON CONFLICT (id, user_email) DO NOTHING
  `);
  stmt.run({
    id: email.id,
    userEmail: email.userEmail,
    conversationId: email.conversationId,
    subject: email.subject,
    toRecipients: JSON.stringify(email.toRecipients),
    sentAt: email.sentAt,
    webLink: email.webLink,
  });
}

export function markReplied(id: string, userEmail: string, repliedAt: string) {
  db.prepare(
    `UPDATE tracked_emails SET status = 'replied', replied_at = @repliedAt
     WHERE id = @id AND user_email = @userEmail AND status != 'replied'`
  ).run({ id, userEmail, repliedAt });
}

export function dismissEmail(id: string, userEmail: string) {
  db.prepare(
    `UPDATE tracked_emails SET status = 'dismissed' WHERE id = @id AND user_email = @userEmail`
  ).run({ id, userEmail });
}

export function recordFollowUp(id: string, userEmail: string, at: string) {
  db.prepare(
    `UPDATE tracked_emails SET last_follow_up_at = @at, follow_up_count = follow_up_count + 1
     WHERE id = @id AND user_email = @userEmail`
  ).run({ id, userEmail, at });
}

export function listTrackedEmails(userEmail: string): TrackedEmail[] {
  return db
    .prepare(
      `SELECT * FROM tracked_emails WHERE user_email = @userEmail ORDER BY sent_at DESC`
    )
    .all({ userEmail }) as TrackedEmail[];
}

export function getTrackedEmail(id: string, userEmail: string): TrackedEmail | undefined {
  return db
    .prepare(`SELECT * FROM tracked_emails WHERE id = @id AND user_email = @userEmail`)
    .get({ id, userEmail }) as TrackedEmail | undefined;
}

export function getFollowUpDelayDays(userEmail: string): number {
  const row = db
    .prepare(`SELECT follow_up_delay_days FROM settings WHERE user_email = @userEmail`)
    .get({ userEmail }) as { follow_up_delay_days: number } | undefined;
  return row?.follow_up_delay_days ?? DEFAULT_DELAY_DAYS;
}

export function setFollowUpDelayDays(userEmail: string, days: number) {
  db.prepare(
    `INSERT INTO settings (user_email, follow_up_delay_days) VALUES (@userEmail, @days)
     ON CONFLICT (user_email) DO UPDATE SET follow_up_delay_days = @days`
  ).run({ userEmail, days });
}

export default db;
