import { config } from "./config";
import { devicesByUser, getLastSeen, setLastSeen } from "./store";
import { fetchAssignedTickets } from "./glpiClient";
import { sendPush } from "./apns";

async function pollOnce(): Promise<void> {
  const byUser = await devicesByUser();
  if (byUser.size === 0) return;

  for (const [glpiUserId, devices] of byUser) {
    try {
      const tickets = await fetchAssignedTickets(glpiUserId);
      const previouslySeen = await getLastSeen(glpiUserId);
      const nextSeen: Record<string, number> = {};

      for (const ticket of tickets) {
        const key = String(ticket.id);
        nextSeen[key] = ticket.status;
        const previousStatus = previouslySeen[key];

        let notification: { title: string; body: string } | null = null;
        if (previousStatus === undefined) {
          notification = {
            title: "Nouvelle intervention assignée",
            body: `#${ticket.id} — ${ticket.title}`
          };
        } else if (previousStatus !== ticket.status) {
          notification = {
            title: `Ticket #${ticket.id} mis à jour`,
            body: ticket.title
          };
        }

        if (notification) {
          for (const device of devices) {
            try {
              await sendPush(device.deviceToken, notification.title, notification.body);
            } catch (error) {
              console.error(`[poller] échec envoi push à ${device.deviceToken}:`, error);
            }
          }
        }
      }

      await setLastSeen(glpiUserId, nextSeen);
    } catch (error) {
      console.error(`[poller] échec du sondage GLPI pour l'utilisateur ${glpiUserId}:`, error);
    }
  }
}

export function startPolling(): void {
  const intervalMs = Math.max(30, config.pollIntervalSeconds) * 1000;
  console.log(`[poller] démarrage, intervalle = ${intervalMs / 1000}s`);
  pollOnce().catch((error) => console.error("[poller] erreur lors du premier sondage:", error));
  setInterval(() => {
    pollOnce().catch((error) => console.error("[poller] erreur de sondage:", error));
  }, intervalMs);
}
