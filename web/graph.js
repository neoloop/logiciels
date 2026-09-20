import { msalConfig, graphScopes, workbookPath } from "./authConfig.js";

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

async function graphFetch(path, options = {}) {
  const token = await getToken();
  const response = await fetch(`https://graph.microsoft.com/v1.0${workbookPath}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Erreur Microsoft Graph (${response.status}) : ${text}`);
  }
  if (response.status === 204) return null;
  return response.json();
}

function cellString(value) {
  if (typeof value === "number") return String(value);
  if (typeof value === "boolean") return value ? "TRUE" : "FALSE";
  return value ?? "";
}

export async function rows(table) {
  const data = await graphFetch(`/tables/${table}/rows`);
  return (data.value || []).map((item) => (item.values?.[0] || []).map(cellString));
}

export async function addRow(table, values) {
  await graphFetch(`/tables/${table}/rows`, {
    method: "POST",
    body: JSON.stringify({ values: [values] }),
  });
}

export async function updateRow(table, index, values) {
  await graphFetch(`/tables/${table}/rows/itemAt(index=${index})`, {
    method: "PATCH",
    body: JSON.stringify({ values: [values] }),
  });
}

// Supprimer décale l'index de chaque ligne suivante d'un cran : pour supprimer plusieurs
// lignes d'une même table, il faut les supprimer de l'index le plus haut vers le plus bas.
export async function deleteRow(table, index) {
  await graphFetch(`/tables/${table}/rows/itemAt(index=${index})/delete`, { method: "POST" });
}
