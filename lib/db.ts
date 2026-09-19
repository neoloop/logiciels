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
    follow_up_delay_days INTEGER NOT NULL DEFAULT 3,
    sync_interval_minutes INTEGER NOT NULL DEFAULT 15,
    last_synced_at TEXT
  );

  CREATE TABLE IF NOT EXISTS oauth_tokens (
    user_email TEXT PRIMARY KEY,
    refresh_token TEXT NOT NULL,
    access_token TEXT,
    access_token_expires INTEGER,
    updated_at TEXT NOT NULL
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

export interface Settings {
  followUpDelayDays: number;
  syncIntervalMinutes: number;
  lastSyncedAt: string | null;
}

export interface OAuthTokens {
  refreshToken: string;
  accessToken: string | null;
  accessTokenExpires: number | null;
}

const DEFAULT_DELAY_DAYS = Number(process.env.DEFAULT_FOLLOW_UP_DELAY_DAYS ?? 3);
const DEFAULT_SYNC_INTERVAL_MINUTES = Number(process.env.DEFAULT_SYNC_INTERVAL_MINUTES ?? 15);

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

function ensureSettingsRow(userEmail: string) {
  db.prepare(
    `INSERT INTO settings (user_email, follow_up_delay_days, sync_interval_minutes)
     VALUES (@userEmail, @delay, @interval)
     ON CONFLICT (user_email) DO NOTHING`
  ).run({ userEmail, delay: DEFAULT_DELAY_DAYS, interval: DEFAULT_SYNC_INTERVAL_MINUTES });
}

export function getSettings(userEmail: string): Settings {
  const row = db
    .prepare(
      `SELECT follow_up_delay_days, sync_interval_minutes, last_synced_at FROM settings WHERE user_email = @userEmail`
    )
    .get({ userEmail }) as
    | { follow_up_delay_days: number; sync_interval_minutes: number; last_synced_at: string | null }
    | undefined;

  return {
    followUpDelayDays: row?.follow_up_delay_days ?? DEFAULT_DELAY_DAYS,
    syncIntervalMinutes: row?.sync_interval_minutes ?? DEFAULT_SYNC_INTERVAL_MINUTES,
    lastSyncedAt: row?.last_synced_at ?? null,
  };
}

export function getFollowUpDelayDays(userEmail: string): number {
  return getSettings(userEmail).followUpDelayDays;
}

export function setFollowUpDelayDays(userEmail: string, days: number) {
  ensureSettingsRow(userEmail);
  db.prepare(`UPDATE settings SET follow_up_delay_days = @days WHERE user_email = @userEmail`).run({
    userEmail,
    days,
  });
}

export function setSyncIntervalMinutes(userEmail: string, minutes: number) {
  ensureSettingsRow(userEmail);
  db.prepare(`UPDATE settings SET sync_interval_minutes = @minutes WHERE user_email = @userEmail`).run({
    userEmail,
    minutes,
  });
}

export function touchLastSyncedAt(userEmail: string, at: string) {
  ensureSettingsRow(userEmail);
  db.prepare(`UPDATE settings SET last_synced_at = @at WHERE user_email = @userEmail`).run({
    userEmail,
    at,
  });
}

export function listUserEmailsWithSyncEnabled(): string[] {
  const rows = db
    .prepare(`SELECT user_email FROM settings WHERE sync_interval_minutes > 0`)
    .all() as { user_email: string }[];
  return rows.map((r) => r.user_email);
}

export function saveOAuthTokens(
  userEmail: string,
  tokens: { refreshToken: string; accessToken?: string | null; accessTokenExpires?: number | null }
) {
  db.prepare(
    `INSERT INTO oauth_tokens (user_email, refresh_token, access_token, access_token_expires, updated_at)
     VALUES (@userEmail, @refreshToken, @accessToken, @accessTokenExpires, @updatedAt)
     ON CONFLICT (user_email) DO UPDATE SET
       refresh_token = @refreshToken,
       access_token = @accessToken,
       access_token_expires = @accessTokenExpires,
       updated_at = @updatedAt`
  ).run({
    userEmail,
    refreshToken: tokens.refreshToken,
    accessToken: tokens.accessToken ?? null,
    accessTokenExpires: tokens.accessTokenExpires ?? null,
    updatedAt: new Date().toISOString(),
  });
}

export function getOAuthTokens(userEmail: string): OAuthTokens | undefined {
  const row = db
    .prepare(
      `SELECT refresh_token, access_token, access_token_expires FROM oauth_tokens WHERE user_email = @userEmail`
    )
    .get({ userEmail }) as
    | { refresh_token: string; access_token: string | null; access_token_expires: number | null }
    | undefined;

  if (!row) return undefined;
  return {
    refreshToken: row.refresh_token,
    accessToken: row.access_token,
    accessTokenExpires: row.access_token_expires,
  };
}

export function deleteOAuthTokens(userEmail: string) {
  db.prepare(`DELETE FROM oauth_tokens WHERE user_email = @userEmail`).run({ userEmail });
}

export default db;
