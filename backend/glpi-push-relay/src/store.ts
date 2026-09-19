import { promises as fs } from "node:fs";
import path from "node:path";
import { config } from "./config";

export interface DeviceRecord {
  deviceToken: string;
  glpiUserId: number;
  platform: string;
  registeredAt: string;
}

interface StoreData {
  devices: DeviceRecord[];
  /** glpiUserId -> ticketId -> last known status */
  lastSeen: Record<string, Record<string, number>>;
}

const empty: StoreData = { devices: [], lastSeen: {} };

let cache: StoreData | null = null;

async function load(): Promise<StoreData> {
  if (cache) return cache;
  let data: StoreData;
  try {
    const raw = await fs.readFile(config.dataFile, "utf8");
    data = { ...empty, ...JSON.parse(raw) };
  } catch {
    data = { ...empty };
  }
  cache = data;
  return data;
}

async function persist(): Promise<void> {
  if (!cache) return;
  await fs.mkdir(path.dirname(config.dataFile), { recursive: true });
  await fs.writeFile(config.dataFile, JSON.stringify(cache, null, 2), "utf8");
}

export async function addDevice(record: Omit<DeviceRecord, "registeredAt">): Promise<void> {
  const data = await load();
  data.devices = data.devices.filter((d) => d.deviceToken !== record.deviceToken);
  data.devices.push({ ...record, registeredAt: new Date().toISOString() });
  await persist();
}

export async function removeDevice(deviceToken: string): Promise<void> {
  const data = await load();
  data.devices = data.devices.filter((d) => d.deviceToken !== deviceToken);
  await persist();
}

export async function devicesByUser(): Promise<Map<number, DeviceRecord[]>> {
  const data = await load();
  const map = new Map<number, DeviceRecord[]>();
  for (const device of data.devices) {
    const list = map.get(device.glpiUserId) ?? [];
    list.push(device);
    map.set(device.glpiUserId, list);
  }
  return map;
}

export async function getLastSeen(glpiUserId: number): Promise<Record<string, number>> {
  const data = await load();
  return data.lastSeen[String(glpiUserId)] ?? {};
}

export async function setLastSeen(glpiUserId: number, seen: Record<string, number>): Promise<void> {
  const data = await load();
  data.lastSeen[String(glpiUserId)] = seen;
  await persist();
}
