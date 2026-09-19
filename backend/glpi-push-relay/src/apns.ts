import http2 from "node:http2";
import { readFileSync } from "node:fs";
import jwt from "jsonwebtoken";
import { config } from "./config";

let cachedProviderToken: { token: string; issuedAt: number } | null = null;

/** APNs provider tokens are valid up to 1h; refresh a bit before that. */
function providerToken(): string {
  const now = Math.floor(Date.now() / 1000);
  if (cachedProviderToken && now - cachedProviderToken.issuedAt < 50 * 60) {
    return cachedProviderToken.token;
  }
  const privateKey = readFileSync(config.apns.keyPath, "utf8");
  const token = jwt.sign({ iss: config.apns.teamId, iat: now }, privateKey, {
    algorithm: "ES256",
    header: { alg: "ES256", kid: config.apns.keyId }
  });
  cachedProviderToken = { token, issuedAt: now };
  return token;
}

export async function sendPush(deviceToken: string, title: string, body: string): Promise<void> {
  const host = config.apns.production ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const client = http2.connect(`https://${host}`);

  await new Promise<void>((resolve, reject) => {
    client.on("error", reject);

    const req = client.request({
      ":method": "POST",
      ":path": `/3/device/${deviceToken}`,
      authorization: `bearer ${providerToken()}`,
      "apns-topic": config.apns.bundleId,
      "apns-push-type": "alert",
      "content-type": "application/json"
    });

    let status = 0;
    let responseBody = "";

    req.on("response", (headers) => {
      status = Number(headers[":status"] ?? 0);
    });
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      responseBody += chunk;
    });
    req.on("end", () => {
      client.close();
      if (status >= 200 && status < 300) {
        resolve();
      } else {
        reject(new Error(`APNs a répondu ${status} pour ${deviceToken}: ${responseBody}`));
      }
    });
    req.on("error", (error) => {
      client.close();
      reject(error);
    });

    req.write(JSON.stringify({ aps: { alert: { title, body }, sound: "default" } }));
    req.end();
  });
}
