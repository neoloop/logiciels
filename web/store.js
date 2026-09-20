import { downloadStore, uploadStore } from "./graph.js";

const VALID_STATUSES = ["À faire", "En cours", "Fait"];

function formatDate(date) {
  return date.toISOString().slice(0, 10);
}

function parseDate(raw) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(raw)) return null;
  const [y, m, d] = raw.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

export function projectDuration(project) {
  const days = Math.round((project.endDate.getTime() - project.startDate.getTime()) / 86400000);
  return Math.max(days + 1, 0);
}

export const store = {
  projects: [],
  tasks: [],
  isSyncing: false,
  syncError: null,
};

export function tasksFor(projectId) {
  return store.tasks.filter((t) => t.projectId === projectId).sort((a, b) => a.order - b.order);
}

export async function refresh() {
  store.isSyncing = true;
  store.syncError = null;
  try {
    const file = await downloadStore();
    if (!file) {
      store.projects = [];
      store.tasks = [];
      return;
    }

    store.projects = (file.projects || [])
      .map((r) => {
        const startDate = parseDate(r.startDate);
        const endDate = parseDate(r.endDate);
        if (!startDate || !endDate) return null;
        return { id: r.id, name: r.name, startDate, endDate, notes: r.notes || "" };
      })
      .filter(Boolean)
      .sort((a, b) => a.startDate - b.startDate);

    store.tasks = (file.tasks || [])
      .filter((r) => VALID_STATUSES.includes(r.status) && Number.isInteger(r.order))
      .map((r) => ({ id: r.id, projectId: r.projectId, name: r.name, status: r.status, order: r.order }));
  } catch (error) {
    store.syncError = error.message;
  } finally {
    store.isSyncing = false;
  }
}

async function persist() {
  const file = {
    projects: store.projects.map((p) => ({
      id: p.id,
      name: p.name,
      startDate: formatDate(p.startDate),
      endDate: formatDate(p.endDate),
      notes: p.notes || "",
    })),
    tasks: store.tasks.map((t) => ({ id: t.id, projectId: t.projectId, name: t.name, status: t.status, order: t.order })),
  };
  try {
    await uploadStore(file);
  } catch (error) {
    store.syncError = error.message;
  }
}

export async function saveProject(project) {
  const index = store.projects.findIndex((p) => p.id === project.id);
  if (index >= 0) store.projects[index] = project;
  else store.projects.push(project);
  await persist();
}

export async function deleteProject(project) {
  store.projects = store.projects.filter((p) => p.id !== project.id);
  store.tasks = store.tasks.filter((t) => t.projectId !== project.id);
  await persist();
}

export async function saveTask(task) {
  const index = store.tasks.findIndex((t) => t.id === task.id);
  if (index >= 0) store.tasks[index] = task;
  else store.tasks.push(task);
  await persist();
}

export async function deleteTask(task) {
  store.tasks = store.tasks.filter((t) => t.id !== task.id);
  await persist();
}

export const TASK_STATUSES = VALID_STATUSES;
