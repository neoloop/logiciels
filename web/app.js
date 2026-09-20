import * as authGraph from "./graph.js";
import { store, tasksFor, projectDuration, refresh, saveProject, deleteProject, saveTask, deleteTask } from "./store.js";
import { renderGantt } from "./gantt.js";

const signInScreen = document.getElementById("sign-in-screen");
const appMain = document.getElementById("app-main");
const accountBox = document.getElementById("account-box");
const authError = document.getElementById("auth-error");

const projectList = document.getElementById("project-list");
const syncStatus = document.getElementById("sync-status");
const syncErrorEl = document.getElementById("sync-error");

const projectDialog = document.getElementById("project-dialog");
const projectForm = document.getElementById("project-form");
const taskDialog = document.getElementById("task-dialog");
const taskForm = document.getElementById("task-form");

const yearSelect = document.getElementById("year-select");
const ganttContainer = document.getElementById("gantt-container");

const openTaskLists = new Set();

async function bootstrap() {
  document.getElementById("sign-in-btn").addEventListener("click", () => {
    authGraph.signIn().catch((error) => {
      authError.textContent = error.message;
    });
  });

  document.querySelectorAll("[data-close-dialog]").forEach((btn) => {
    btn.addEventListener("click", () => document.getElementById(btn.dataset.closeDialog).close());
  });

  document.getElementById("new-project-btn").addEventListener("click", () => openProjectDialog(null));
  projectForm.addEventListener("submit", onProjectFormSubmit);
  taskForm.addEventListener("submit", onTaskFormSubmit);

  document.getElementById("project-start").addEventListener("change", updateDurationPreview);
  document.getElementById("project-end").addEventListener("change", updateDurationPreview);

  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.addEventListener("click", () => switchTab(btn.dataset.tab));
  });

  yearSelect.addEventListener("change", renderGanttTab);

  try {
    const account = await authGraph.initAuth();
    if (account) {
      showApp(account);
      await syncAndRender();
    } else {
      signInScreen.hidden = false;
    }
  } catch (error) {
    authError.textContent = error.message;
    signInScreen.hidden = false;
  }
}

function showApp(account) {
  signInScreen.hidden = true;
  appMain.hidden = false;
  accountBox.innerHTML = "";

  const name = document.createElement("span");
  name.textContent = account.username;
  name.className = "sync-status";
  name.style.marginRight = "10px";

  const signOutBtn = document.createElement("button");
  signOutBtn.className = "btn-secondary";
  signOutBtn.textContent = "Se déconnecter";
  signOutBtn.addEventListener("click", () => authGraph.signOut());

  accountBox.appendChild(name);
  accountBox.appendChild(signOutBtn);
}

async function syncAndRender() {
  syncStatus.textContent = "Synchronisation…";
  await refresh();
  syncStatus.textContent = "";
  syncErrorEl.textContent = store.syncError || "";
  renderProjectList();
  populateYearSelect();
  renderGanttTab();
}

function switchTab(tab) {
  document.querySelectorAll(".tab-btn").forEach((btn) => btn.classList.toggle("active", btn.dataset.tab === tab));
  document.querySelectorAll(".tab-panel").forEach((panel) => panel.classList.toggle("active", panel.id === `tab-${tab}`));
  if (tab === "gantt") renderGanttTab();
}

function renderProjectList() {
  projectList.innerHTML = "";

  if (store.projects.length === 0) {
    const empty = document.createElement("p");
    empty.className = "empty-state";
    empty.textContent = "Aucun projet. Ajoutez-en un avec le bouton ci-dessus.";
    projectList.appendChild(empty);
    return;
  }

  store.projects.forEach((project) => {
    projectList.appendChild(buildProjectCard(project));
  });
}

function buildProjectCard(project) {
  const card = document.createElement("div");
  card.className = "project-card";

  const head = document.createElement("div");
  head.className = "project-card-head";

  const info = document.createElement("div");
  info.innerHTML = `
    <h3>${escapeHtml(project.name)}</h3>
    <div class="project-meta">${formatDate(project.startDate)} → ${formatDate(project.endDate)}</div>
    <div class="project-duration">${projectDuration(project)} jour${projectDuration(project) > 1 ? "s" : ""}</div>
  `;
  head.addEventListener("click", () => {
    if (openTaskLists.has(project.id)) openTaskLists.delete(project.id);
    else openTaskLists.add(project.id);
    tasksSection.classList.toggle("open", openTaskLists.has(project.id));
  });

  const actions = document.createElement("div");
  actions.className = "project-actions";

  const editBtn = document.createElement("button");
  editBtn.className = "btn-icon";
  editBtn.textContent = "✏️";
  editBtn.title = "Modifier";
  editBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    openProjectDialog(project);
  });

  const deleteBtn = document.createElement("button");
  deleteBtn.className = "btn-icon";
  deleteBtn.textContent = "🗑️";
  deleteBtn.title = "Supprimer";
  deleteBtn.addEventListener("click", async (e) => {
    e.stopPropagation();
    if (!confirm(`Supprimer le projet « ${project.name} » et ses étapes ?`)) return;
    await deleteProject(project);
    await syncAndRender();
  });

  actions.appendChild(editBtn);
  actions.appendChild(deleteBtn);
  head.appendChild(info);
  head.appendChild(actions);
  card.appendChild(head);

  if (!project.notes) {
    // no-op, keep layout simple when there are no notes
  } else {
    const notes = document.createElement("p");
    notes.className = "project-meta";
    notes.textContent = project.notes;
    card.appendChild(notes);
  }

  const tasksSection = document.createElement("div");
  tasksSection.className = "project-tasks";
  if (openTaskLists.has(project.id)) tasksSection.classList.add("open");

  const projectTasks = tasksFor(project.id);
  if (projectTasks.length === 0) {
    const empty = document.createElement("p");
    empty.className = "project-meta";
    empty.textContent = "Aucune étape pour l'instant.";
    tasksSection.appendChild(empty);
  } else {
    projectTasks.forEach((task) => tasksSection.appendChild(buildTaskRow(task)));
  }

  const addTaskBtn = document.createElement("button");
  addTaskBtn.className = "btn-secondary add-task-row";
  addTaskBtn.textContent = "+ Ajouter une étape";
  addTaskBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    openTaskDialog(project.id, null, projectTasks.length);
  });
  tasksSection.appendChild(addTaskBtn);

  card.appendChild(tasksSection);
  return card;
}

function buildTaskRow(task) {
  const row = document.createElement("div");
  row.className = "task-row";

  const name = document.createElement("span");
  name.className = "task-name";
  name.textContent = task.name;
  name.addEventListener("click", () => openTaskDialog(task.projectId, task, task.order));

  const statusSelect = document.createElement("select");
  statusSelect.className = "status-select";
  ["À faire", "En cours", "Fait"].forEach((status) => {
    const option = document.createElement("option");
    option.value = status;
    option.textContent = status;
    option.selected = status === task.status;
    statusSelect.appendChild(option);
  });
  statusSelect.addEventListener("click", (e) => e.stopPropagation());
  statusSelect.addEventListener("change", async () => {
    await saveTask({ ...task, status: statusSelect.value });
    await syncAndRender();
  });

  const deleteBtn = document.createElement("button");
  deleteBtn.className = "btn-icon";
  deleteBtn.textContent = "🗑️";
  deleteBtn.addEventListener("click", async (e) => {
    e.stopPropagation();
    await deleteTask(task);
    await syncAndRender();
  });

  row.appendChild(name);
  row.appendChild(statusSelect);
  row.appendChild(deleteBtn);
  return row;
}

function openProjectDialog(project) {
  document.getElementById("project-dialog-title").textContent = project ? "Modifier le projet" : "Nouveau projet";
  document.getElementById("project-id").value = project?.id || "";
  document.getElementById("project-name").value = project?.name || "";
  document.getElementById("project-start").value = project ? toInputDate(project.startDate) : "";
  document.getElementById("project-end").value = project ? toInputDate(project.endDate) : "";
  document.getElementById("project-notes").value = project?.notes || "";
  updateDurationPreview();
  projectDialog.showModal();
}

function updateDurationPreview() {
  const start = document.getElementById("project-start").value;
  const end = document.getElementById("project-end").value;
  const preview = document.getElementById("project-duration-preview");
  if (!start || !end) {
    preview.textContent = "";
    return;
  }
  const days = Math.round((new Date(end) - new Date(start)) / 86400000) + 1;
  preview.textContent = days > 0 ? `Durée : ${days} jour${days > 1 ? "s" : ""}` : "Date de fin avant la date de début";
}

async function onProjectFormSubmit(event) {
  event.preventDefault();
  const id = document.getElementById("project-id").value || crypto.randomUUID();
  const project = {
    id,
    name: document.getElementById("project-name").value.trim(),
    startDate: fromInputDate(document.getElementById("project-start").value),
    endDate: fromInputDate(document.getElementById("project-end").value),
    notes: document.getElementById("project-notes").value.trim(),
  };
  projectDialog.close();
  await saveProject(project);
  await syncAndRender();
}

function openTaskDialog(projectId, task, nextOrder) {
  document.getElementById("task-dialog-title").textContent = task ? "Modifier l'étape" : "Nouvelle étape";
  document.getElementById("task-id").value = task?.id || "";
  document.getElementById("task-project-id").value = projectId;
  document.getElementById("task-order").value = task ? task.order : nextOrder;
  document.getElementById("task-name").value = task?.name || "";
  document.getElementById("task-status").value = task?.status || "À faire";
  taskDialog.showModal();
}

async function onTaskFormSubmit(event) {
  event.preventDefault();
  const task = {
    id: document.getElementById("task-id").value || crypto.randomUUID(),
    projectId: document.getElementById("task-project-id").value,
    order: Number(document.getElementById("task-order").value),
    name: document.getElementById("task-name").value.trim(),
    status: document.getElementById("task-status").value,
  };
  taskDialog.close();
  await saveTask(task);
  await syncAndRender();
}

function populateYearSelect() {
  const years = new Set([new Date().getFullYear()]);
  store.projects.forEach((project) => {
    years.add(project.startDate.getUTCFullYear());
    years.add(project.endDate.getUTCFullYear());
  });
  const sorted = [...years].sort((a, b) => a - b);
  const previous = yearSelect.value;
  yearSelect.innerHTML = "";
  sorted.forEach((year) => {
    const option = document.createElement("option");
    option.value = String(year);
    option.textContent = String(year);
    yearSelect.appendChild(option);
  });
  yearSelect.value = previous && sorted.includes(Number(previous)) ? previous : String(new Date().getFullYear());
}

function renderGanttTab() {
  const year = Number(yearSelect.value || new Date().getFullYear());
  const yearProjects = store.projects.filter(
    (p) => p.startDate.getUTCFullYear() <= year && p.endDate.getUTCFullYear() >= year
  );
  renderGantt(ganttContainer, yearProjects, store.tasks, year);
}

function formatDate(date) {
  return date.toLocaleDateString("fr-FR", { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" });
}

function toInputDate(date) {
  return date.toISOString().slice(0, 10);
}

function fromInputDate(value) {
  const [y, m, d] = value.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

function escapeHtml(text) {
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

bootstrap();
