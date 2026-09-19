import type { TrackedEmail } from "@/lib/db";

export type DisplayStatus = "replied" | "dismissed" | "needs_follow_up" | "waiting";

export function computeDisplayStatus(email: TrackedEmail, delayDays: number): DisplayStatus {
  if (email.status === "replied") return "replied";
  if (email.status === "dismissed") return "dismissed";

  const sentAt = new Date(email.sent_at).getTime();
  const deadline = sentAt + delayDays * 24 * 60 * 60 * 1000;

  return Date.now() >= deadline ? "needs_follow_up" : "waiting";
}
