import * as graph from "./graph.js";

const EXCEL_EPOCH_MS = Date.UTC(1899, 11, 30);
const VALID_STATUSES = ["À faire", "En cours", "Fait"];

function formatDate(date) {
  return date.toISOString().slice(0, 10);
}

function parseDate(raw) {
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    const [y, m, d] = raw.split("-").map(Number);
    return new Date(Date.UTC(y, m - 1, d));
  }
  const serial = Number(raw);
  if (!Number.isNaN(serial) && raw !== "") return new Date(EXCEL_EPOCH_MS + serial * 86400000);
  return null;
}

export function projectDuration(project) {
  const days = Math.round((project.endDate.getTime() - project.startDate.getTime()) / 86400000);
  return Math.max(days + 1, 0);
}

export const store = {
  projects: [],
  tasks: [],
  projectRowIndex: new Map(),
  taskRowIndex: new Map(),
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
    const [projectRows, taskRows] = await Promise.all([graph.rows("Projects"), graph.rows("Tasks")]);

    const projects = [];
    const projectRowIndex = new Map();
    projectRows.forEach((row, index) => {
      if (row.length < 6) return;
      const startDate = parseDate(row[2]);
      const endDate = parseDate(row[3]);
      if (!startDate || !endDate) return;
      projects.push({ id: row[0], name: row[1], startDate, endDate, notes: row[5] });
      projectRowIndex.set(row[0], index);
    });

    const tasks = [];
    const taskRowIndex = new Map();
    taskRows.forEach((row, index) => {
      if (row.length < 5) return;
      const order = Number(row[4]);
      if (!VALID_STATUSES.includes(row[3]) || Number.isNaN(order)) return;
      tasks.push({ id: row[0], projectId: row[1], name: row[2], status: row[3], order });
      taskRowIndex.set(row[0], index);
    });

    store.projects = projects.sort((a, b) => a.startDate - b.startDate);
    store.tasks = tasks;
    store.projectRowIndex = projectRowIndex;
    store.taskRowIndex = taskRowIndex;
  } catch (error) {
    store.syncError = error.message;
  } finally {
    store.isSyncing = false;
  }
}

export async function saveProject(project) {
  const values = [
    project.id,
    project.name,
    formatDate(project.startDate),
    formatDate(project.endDate),
    String(projectDuration(project)),
    project.notes || "",
  ];
  const index = store.projectRowIndex.get(project.id);
  if (index !== undefined) await graph.updateRow("Projects", index, values);
  else await graph.addRow("Projects", values);
  await refresh();
}

export async function deleteProject(project) {
  const relatedIndices = tasksFor(project.id)
    .map((t) => store.taskRowIndex.get(t.id))
    .filter((i) => i !== undefined)
    .sort((a, b) => b - a);
  for (const index of relatedIndices) {
    await graph.deleteRow("Tasks", index);
  }
  const index = store.projectRowIndex.get(project.id);
  if (index !== undefined) await graph.deleteRow("Projects", index);
  await refresh();
}

export async function saveTask(task) {
  const values = [task.id, task.projectId, task.name, task.status, String(task.order)];
  const index = store.taskRowIndex.get(task.id);
  if (index !== undefined) await graph.updateRow("Tasks", index, values);
  else await graph.addRow("Tasks", values);
  await refresh();
}

export async function deleteTask(task) {
  const index = store.taskRowIndex.get(task.id);
  if (index !== undefined) await graph.deleteRow("Tasks", index);
  await refresh();
}

export const TASK_STATUSES = VALID_STATUSES;
