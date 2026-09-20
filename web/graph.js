import { msalConfig, graphScopes, dataFileName } from "./authConfig.js";

const msalInstance = new msal.PublicClientApplication(msalConfig);
let account = null;

export async function initAuth() {
  await msalInstance.initialize();
  const response = await msalInstance.handleRedirectPromise();
  if (response) {
    account = response.account;
  } else {
    const accounts = msalInstance.getAllAccounts();
    if (accounts.length > 0) account = accounts[0];
  }
  return account;
}

export function currentAccount() {
  return account;
}

export function signIn() {
  return msalInstance.loginRedirect({ scopes: graphScopes });
}

export function signOut() {
  return msalInstance.logoutRedirect();
}

async function getToken() {
  if (!account) throw new Error("Non connecté à Microsoft.");
  try {
    const result = await msalInstance.acquireTokenSilent({ scopes: graphScopes, account });
    return result.accessToken;
  } catch (silentError) {
    const result = await msalInstance.acquireTokenPopup({ scopes: graphScopes });
    account = result.account;
    return result.accessToken;
  }
}

const contentUrl = () => `https://graph.microsoft.com/v1.0/me/drive/root:/${dataFileName}:/content`;

// Le fichier entier est téléchargé, modifié en mémoire, puis renvoyé en entier à chaque
// changement : pas de serveur, pas de mise à jour partielle. Adapté à un usage par une
// personne sur un appareil à la fois.

/** null si le fichier n'existe pas encore (premier lancement) — traité comme un magasin vide. */
export async function downloadStore() {
  const token = await getToken();
  const response = await fetch(contentUrl(), {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (response.status === 404) return null;
  if (!response.ok) {
    throw new Error(`Erreur Microsoft Graph (${response.status}) : ${await response.text()}`);
  }
  return response.json();
}

export async function uploadStore(data) {
  const token = await getToken();
  const response = await fetch(contentUrl(), {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });
  if (!response.ok) {
    throw new Error(`Erreur Microsoft Graph (${response.status}) : ${await response.text()}`);
  }
}
