import { config } from "./config";

/**
 * Minimal service-account GLPI REST client used to poll ticket state on
 * behalf of every registered technician. Mirrors the logic of the iOS app's
 * GLPIAPIClient, but only needs the read path.
 */

export interface TicketState {
  id: number;
  title: string;
  status: number;
}

let sessionToken: string | null = null;

function apiURL(pathAndQuery: string): string {
  return `${config.glpiUrl}/apirest.php/${pathAndQuery}`;
}

async function initSession(): Promise<string> {
  const response = await fetch(apiURL("initSession"), {
    headers: {
      "App-Token": config.glpiAppToken,
      Authorization: `user_token ${config.glpiUserToken}`
    }
  });
  if (!response.ok) {
    throw new Error(`initSession GLPI a échoué (${response.status}): ${await response.text()}`);
  }
  const body = (await response.json()) as { session_token: string };
  return body.session_token;
}

async function ensureSession(): Promise<string> {
  if (!sessionToken) {
    sessionToken = await initSession();
  }
  return sessionToken;
}

async function authorizedFetch(pathAndQuery: string): Promise<Response> {
  const token = await ensureSession();
  const response = await fetch(apiURL(pathAndQuery), {
    headers: {
      "App-Token": config.glpiAppToken,
      "Session-Token": token
    }
  });
  if (response.status === 401) {
    // Session expired server-side; re-authenticate once and retry.
    sessionToken = null;
    const retryToken = await ensureSession();
    return fetch(apiURL(pathAndQuery), {
      headers: {
        "App-Token": config.glpiAppToken,
        "Session-Token": retryToken
      }
    });
  }
  return response;
}

export async function fetchAssignedTickets(glpiUserId: number): Promise<TicketState[]> {
  const query = new URLSearchParams({
    range: "0-99",
    "criteria[0][field]": config.fields.assignedTechnician,
    "criteria[0][searchtype]": "equals",
    "criteria[0][value]": String(glpiUserId),
    "criteria[1][link]": "AND",
    "criteria[1][field]": config.fields.status,
    "criteria[1][searchtype]": "notequals",
    "criteria[1][value]": "6",
    "forcedisplay[0]": config.fields.id,
    "forcedisplay[1]": config.fields.title,
    "forcedisplay[2]": config.fields.status
  });

  const response = await authorizedFetch(`search/Ticket?${query.toString()}`);
  if (!response.ok) {
    throw new Error(`search/Ticket GLPI a échoué (${response.status}): ${await response.text()}`);
  }
  const body = (await response.json()) as { data?: Record<string, unknown>[] };

  return (body.data ?? [])
    .map((row) => {
      const id = Number(row[config.fields.id]);
      const status = Number(row[config.fields.status]);
      const title = String(row[config.fields.title] ?? "(sans titre)");
      if (!Number.isFinite(id) || !Number.isFinite(status)) return null;
      return { id, title, status } satisfies TicketState;
    })
    .filter((t): t is TicketState => t !== null);
}
