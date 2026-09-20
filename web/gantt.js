const MONTHS = ["Jan", "Fév", "Mar", "Avr", "Mai", "Juin", "Juil", "Août", "Sep", "Oct", "Nov", "Déc"];

export function renderGantt(container, projects, tasks, year) {
  const yearStart = Date.UTC(year, 0, 1);
  const yearEnd = Date.UTC(year, 11, 31);
  const totalDays = (yearEnd - yearStart) / 86400000 + 1;

  container.innerHTML = "";

  if (projects.length === 0) {
    const empty = document.createElement("p");
    empty.className = "empty-state";
    empty.textContent = `Aucun projet en ${year}.`;
    container.appendChild(empty);
    return;
  }

  const header = document.createElement("div");
  header.className = "gantt-header";
  header.appendChild(spacer());
  MONTHS.forEach((month) => {
    const cell = document.createElement("div");
    cell.className = "gantt-month";
    cell.textContent = month;
    header.appendChild(cell);
  });
  container.appendChild(header);

  const body = document.createElement("div");
  body.className = "gantt-body";

  const todayMs = Date.now();
  if (todayMs >= yearStart && todayMs < yearEnd + 86400000) {
    const marker = document.createElement("div");
    marker.className = "gantt-today";
    marker.style.left = `calc(var(--gantt-label-width) + ${((todayMs - yearStart) / 86400000 / totalDays) * 100}%)`;
    body.appendChild(marker);
  }

  projects.forEach((project) => {
    const row = document.createElement("div");
    row.className = "gantt-row";

    const label = document.createElement("div");
    label.className = "gantt-label";
    label.textContent = project.name;
    label.title = project.name;
    row.appendChild(label);

    const track = document.createElement("div");
    track.className = "gantt-track-wrap";

    const startMs = Math.max(project.startDate.getTime(), yearStart);
    const endMs = Math.min(project.endDate.getTime() + 86400000, yearEnd + 86400000);
    const leftPct = ((startMs - yearStart) / 86400000 / totalDays) * 100;
    const widthPct = Math.max(((endMs - startMs) / 86400000 / totalDays) * 100, 0.4);

    const projectTasks = tasks.filter((t) => t.projectId === project.id);
    const doneRatio = projectTasks.length
      ? projectTasks.filter((t) => t.status === "Fait").length / projectTasks.length
      : 0;

    const bar = document.createElement("div");
    bar.className = "gantt-bar";
    bar.style.left = `${leftPct}%`;
    bar.style.width = `${widthPct}%`;
    bar.title = `${project.name} — ${Math.round(doneRatio * 100)}% terminé`;

    const fill = document.createElement("div");
    fill.className = doneRatio >= 1 ? "gantt-fill gantt-fill-done" : "gantt-fill";
    fill.style.width = `${doneRatio * 100}%`;
    bar.appendChild(fill);

    track.appendChild(bar);
    row.appendChild(track);
    body.appendChild(row);
  });

  container.appendChild(body);
}

function spacer() {
  const div = document.createElement("div");
  div.className = "gantt-spacer";
  return div;
}
