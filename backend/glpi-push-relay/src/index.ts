import express from "express";
import { config } from "./config";
import { addDevice, removeDevice } from "./store";
import { startPolling } from "./poller";

const app = express();
app.use(express.json());

function requireApiKey(req: express.Request, res: express.Response, next: express.NextFunction): void {
  if (req.header("X-Relay-Api-Key") !== config.relayApiKey) {
    res.status(401).json({ error: "Clé API du relais invalide." });
    return;
  }
  next();
}

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.post("/register", requireApiKey, async (req, res) => {
  const { deviceToken, glpiUserId, platform } = req.body ?? {};
  if (typeof deviceToken !== "string" || typeof glpiUserId !== "number") {
    res.status(400).json({ error: "deviceToken (string) et glpiUserId (number) sont requis." });
    return;
  }
  await addDevice({ deviceToken, glpiUserId, platform: typeof platform === "string" ? platform : "ios" });
  res.status(201).json({ status: "registered" });
});

app.delete("/register", requireApiKey, async (req, res) => {
  const { deviceToken } = req.body ?? {};
  if (typeof deviceToken !== "string") {
    res.status(400).json({ error: "deviceToken (string) est requis." });
    return;
  }
  await removeDevice(deviceToken);
  res.status(200).json({ status: "removed" });
});

app.listen(config.port, () => {
  console.log(`[relay] à l'écoute sur le port ${config.port}`);
  startPolling();
});
