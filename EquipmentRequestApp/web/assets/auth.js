// Connexion Microsoft et obtention de jetons Microsoft Graph, via MSAL.js.
// Nécessite window.APP_CONFIG (config.js) et la librairie MSAL.js (chargée
// par chaque page depuis un CDN avant ce fichier).

const GRAPH_SCOPES = ["Files.ReadWrite", "Sites.ReadWrite.All", "Mail.Send"];

const msalInstance = new msal.PublicClientApplication({
  auth: {
    clientId: window.APP_CONFIG.clientId,
    authority: `https://login.microsoftonline.com/${window.APP_CONFIG.tenantId}`,
    redirectUri: window.APP_CONFIG.redirectUri,
  },
  cache: {
    // La session reste active entre les visites : pas besoin de se reconnecter
    // à chaque fois sur le même navigateur.
    cacheLocation: "localStorage",
    storeAuthStateInCookie: false,
  },
});

let msalInitialized = false;

async function ensureMsalInitialized() {
  if (!msalInitialized) {
    await msalInstance.initialize();
    msalInitialized = true;
  }
}

// À appeler au chargement de chaque page : termine un éventuel retour de
// connexion, et retourne le compte actif s'il y en a un (sans forcer de
// connexion interactive).
async function getActiveAccount() {
  await ensureMsalInitialized();
  const response = await msalInstance.handleRedirectPromise();
  if (response && response.account) {
    msalInstance.setActiveAccount(response.account);
    return response.account;
  }
  const accounts = msalInstance.getAllAccounts();
  if (accounts.length > 0) {
    msalInstance.setActiveAccount(accounts[0]);
    return accounts[0];
  }
  return null;
}

// Déclenche la connexion interactive (redirige vers login.microsoftonline.com
// puis revient sur cette page).
async function signIn() {
  await ensureMsalInitialized();
  await msalInstance.loginRedirect({ scopes: GRAPH_SCOPES });
}

function signOut() {
  msalInstance.logoutRedirect();
}

// Retourne un jeton d'accès Graph valide pour le compte actif, en réutilisant
// la session existante si possible.
async function getAccessToken() {
  await ensureMsalInitialized();
  const account = msalInstance.getActiveAccount();
  if (!account) {
    throw new Error("Non connecté.");
  }
  try {
    const result = await msalInstance.acquireTokenSilent({ scopes: GRAPH_SCOPES, account });
    return result.accessToken;
  } catch (error) {
    // Jeton silencieux impossible (session expirée, consentement manquant...) :
    // on relance une connexion interactive, qui recharge la page.
    await msalInstance.acquireTokenRedirect({ scopes: GRAPH_SCOPES });
    throw error;
  }
}
