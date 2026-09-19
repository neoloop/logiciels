import "dotenv/config";
import path from "node:path";

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Variable d'environnement manquante : ${name}`);
  }
  return value;
}

export const config = {
  port: Number(process.env.PORT ?? 3000),
  relayApiKey: required("RELAY_API_KEY"),
  pollIntervalSeconds: Number(process.env.POLL_INTERVAL_SECONDS ?? 180),

  glpiUrl: required("GLPI_URL").replace(/\/+$/, ""),
  glpiAppToken: required("GLPI_APP_TOKEN"),
  glpiUserToken: required("GLPI_USER_TOKEN"),

  fields: {
    id: process.env.GLPI_FIELD_ID ?? "2",
    title: process.env.GLPI_FIELD_TITLE ?? "1",
    status: process.env.GLPI_FIELD_STATUS ?? "12",
    assignedTechnician: process.env.GLPI_FIELD_ASSIGNED_TECHNICIAN ?? "5"
  },

  apns: {
    keyPath: required("APNS_KEY_PATH"),
    keyId: required("APNS_KEY_ID"),
    teamId: required("APNS_TEAM_ID"),
    bundleId: required("APNS_BUNDLE_ID"),
    production: (process.env.APNS_PRODUCTION ?? "false").toLowerCase() === "true"
  },

  dataFile: path.resolve(process.env.DATA_FILE ?? "./data/relay-store.json")
};
