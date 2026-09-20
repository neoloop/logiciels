// Envoi du mail avec le PDF en pièce jointe, via Microsoft Graph (POST
// /me/sendMail). Contrairement à l'app iOS (qui ouvre une fenêtre Mail à
// relire avant envoi), un navigateur ne peut pas pré-remplir une fenêtre de
// mail natif avec une pièce jointe : le mail est donc envoyé directement.

async function sendRequestEmail({ accessToken, toEmail, ccEmails, subject, bodyText, pdfDoc, attachmentFilename }) {
  const dataUri = pdfDoc.output("datauristring");
  const base64 = dataUri.substring(dataUri.indexOf(",") + 1);

  const message = {
    message: {
      subject,
      body: { contentType: "Text", content: bodyText },
      toRecipients: [{ emailAddress: { address: toEmail } }],
      ccRecipients: (ccEmails || [])
        .filter(Boolean)
        .map((email) => ({ emailAddress: { address: email } })),
      attachments: [
        {
          "@odata.type": "#microsoft.graph.fileAttachment",
          name: attachmentFilename,
          contentType: "application/pdf",
          contentBytes: base64,
        },
      ],
    },
    saveToSentItems: true,
  };

  const response = await fetch("https://graph.microsoft.com/v1.0/me/sendMail", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(message),
  });

  if (!response.ok) {
    throw new Error(await graphErrorMessage(response));
  }
}
