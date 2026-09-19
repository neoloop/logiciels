import { Client } from "@microsoft/microsoft-graph-client";
import "isomorphic-fetch";

export function getGraphClient(accessToken: string) {
  return Client.init({
    authProvider: (done) => done(null, accessToken),
  });
}

export interface GraphRecipient {
  emailAddress?: { name?: string; address?: string };
}

export interface GraphMessage {
  id: string;
  conversationId: string;
  subject?: string;
  toRecipients?: GraphRecipient[];
  sentDateTime?: string;
  receivedDateTime?: string;
  webLink?: string;
}

/** Escape a single-quoted OData literal (double any embedded single quotes). */
export function escapeODataLiteral(value: string): string {
  return value.replace(/'/g, "''");
}

export async function runWithConcurrency<T, R>(
  items: T[],
  limit: number,
  worker: (item: T) => Promise<R>
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let index = 0;

  async function next(): Promise<void> {
    const current = index++;
    if (current >= items.length) return;
    results[current] = await worker(items[current]);
    return next();
  }

  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, next));
  return results;
}
