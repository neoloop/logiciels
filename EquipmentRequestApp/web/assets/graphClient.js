// Lecture/écriture du fichier JSON partagé (le même que celui lu/écrit par
// l'app iOS) via Microsoft Graph. Toute écriture réécrit l'intégralité du
// fichier, protégée par un ETag pour détecter les écritures concurrentes.

const GRAPH_BASE = "https://graph.microsoft.com/v1.0";

function buildFileUrl() {
  const filePath = window.APP_CONFIG.jsonFilePath.replace(/^\/+|\/+$/g, "");
  // encodeURIComponent encode aussi "/" : on le restaure pour les chemins
  // avec sous-dossier (ex: "Demandes/fichier.json").
  const encodedPath = encodeURIComponent(filePath).replace(/%2F/g, "/");
  return `${GRAPH_BASE}${window.APP_CONFIG.driveBasePath}/root:/${encodedPath}:/content`;
}

// Charge le document. Si le fichier n'existe pas encore sur OneDrive
// (première utilisation), retourne un document vide.
async function fetchRequestsDocument(accessToken) {
  const response = await fetch(buildFileUrl(), {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (response.status === 404) {
    return { document: { schemaVersion: 1, requests: [] }, etag: null };
  }
  if (!response.ok) {
    throw new Error(await graphErrorMessage(response));
  }
  const etag = response.headers.get("ETag");
  const document = await response.json();
  if (!Array.isArray(document.requests)) {
    document.requests = [];
  }
  return { document, etag };
}

// Enregistre le document complet. Si `etag` ne correspond plus au fichier
// (modifié entre-temps par l'app iOS ou l'autre page), Graph renvoie 412 et
// on lève une erreur explicite plutôt que d'écraser silencieusement.
async function saveRequestsDocument(document, etag, accessToken) {
  const headers = {
    Authorization: `Bearer ${accessToken}`,
    "Content-Type": "application/json",
  };
  if (etag) {
    headers["If-Match"] = etag;
  }
  const response = await fetch(buildFileUrl(), {
    method: "PUT",
    headers,
    body: JSON.stringify(document),
  });
  if (response.status === 412) {
    throw new Error("La liste des demandes a été modifiée entre-temps (par l'app iOS ou une autre personne). Rechargez la page et réessayez.");
  }
  if (!response.ok) {
    throw new Error(await graphErrorMessage(response));
  }
}

async function graphErrorMessage(response) {
  try {
    const body = await response.json();
    return `Erreur Microsoft Graph (${response.status}) : ${(body.error && body.error.message) || "erreur inconnue"}`;
  } catch {
    return `Erreur Microsoft Graph (${response.status})`;
  }
}
