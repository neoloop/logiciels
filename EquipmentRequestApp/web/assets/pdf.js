// Génère le PDF de demande de matériel dans le navigateur, avec jsPDF
// (chargé depuis un CDN par chaque page). Reprend la mise en page du PDF
// généré par l'app iOS (PDFGenerator.swift), pour rester cohérent.

function formatDateFR(date) {
  return date.toLocaleDateString("fr-FR", { day: "2-digit", month: "2-digit", year: "numeric" });
}

function generateRequestPDF(request, validatorName) {
  const { jsPDF } = window.jspdf;
  const doc = new jsPDF({ unit: "pt", format: "a4" });
  const margin = 48;
  const pageWidth = doc.internal.pageSize.getWidth();
  const contentWidth = pageWidth - margin * 2;
  let y = margin;

  function draw(text, { size = 13, bold = false, color = "#000000", spacingAfter = 4 } = {}) {
    doc.setFont("helvetica", bold ? "bold" : "normal");
    doc.setFontSize(size);
    doc.setTextColor(color);
    const lines = doc.splitTextToSize(text || "—", contentWidth);
    doc.text(lines, margin, y, { baseline: "top" });
    const lineHeight = size * 1.15;
    y += lines.length * lineHeight + spacingAfter;
  }

  function drawField(label, value) {
    draw(label.toUpperCase(), { size: 12, bold: true, color: "#555555", spacingAfter: 2 });
    draw(value, { size: 13, spacingAfter: 14 });
  }

  function drawSeparator() {
    doc.setDrawColor(200);
    doc.line(margin, y, pageWidth - margin, y);
    y += 16;
  }

  draw("Demande de matériel", { size: 22, bold: true, spacingAfter: 4 });
  draw(`Générée le ${formatDateFR(new Date())}`, { size: 10, color: "#888888", spacingAfter: 20 });
  drawSeparator();

  if (request.reference) drawField("Référence", request.reference);
  drawField("Date de la demande", request.date || formatDateFR(new Date()));
  drawField("Type de matériel demandé", request.equipment);
  if (request.software) drawField("Logiciels associés", request.software);

  drawSeparator();
  drawField("Demandeur (personne qui fait la demande)", `${request.requesterName} — ${request.requesterEmail}`);
  drawField("Bénéficiaire (personne qui recevra le matériel)", `${request.beneficiaryName} — ${request.beneficiaryEmail}`);
  if (request.groupement) drawField("Groupement", request.groupement);
  if (request.phone) drawField("Téléphone", request.phone);

  if (request.opportunity) {
    drawSeparator();
    drawField("Opportunité associée", request.opportunity);
  }

  drawSeparator();
  drawField("Justification de la demande", request.justification);

  drawSeparator();
  drawField("Validé par", validatorName || "—");

  y += 20;
  draw(
    "En signant ci-dessous, le bénéficiaire confirme avoir pris connaissance de cette demande de matériel et accepte les conditions d'utilisation du matériel professionnel.",
    { size: 10, color: "#555555", spacingAfter: 40 }
  );

  const boxHeight = 90;
  const boxWidth = (contentWidth - 24) / 2;
  doc.setDrawColor(150);
  doc.rect(margin, y, boxWidth, boxHeight);
  doc.rect(margin + boxWidth + 24, y, boxWidth, boxHeight);
  doc.setFont("helvetica", "bold");
  doc.setFontSize(12);
  doc.setTextColor("#555555");
  doc.text("Date", margin + 6, y + 16);
  doc.text("Signature du bénéficiaire", margin + boxWidth + 24 + 6, y + 16);

  return doc;
}
