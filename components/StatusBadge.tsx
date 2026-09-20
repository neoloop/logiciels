import type { DisplayStatus } from "@/lib/status";

const LABELS: Record<DisplayStatus, { text: string; classes: string }> = {
  replied: { text: "Répondu", classes: "bg-emerald-100 text-emerald-800" },
  needs_follow_up: { text: "À relancer", classes: "bg-amber-100 text-amber-800" },
  waiting: { text: "En attente", classes: "bg-slate-100 text-slate-700" },
};

export default function StatusBadge({ status }: { status: DisplayStatus }) {
  const { text, classes } = LABELS[status];
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${classes}`}>
      {text}
    </span>
  );
}
