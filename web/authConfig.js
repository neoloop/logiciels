// Valeurs à renseigner après la création de l'app Azure AD — voir docs/SETUP.md.
export const msalConfig = {
  auth: {
    clientId: "REPLACE_WITH_YOUR_CLIENT_ID",
    authority: "https://login.microsoftonline.com/common",
    redirectUri: window.location.origin + window.location.pathname,
  },
  cache: {
    cacheLocation: "localStorage",
  },
};

export const graphScopes = ["User.Read", "Files.ReadWrite"];

// Nom du fichier JSON, à la racine de OneDrive, partagé avec l'app iOS. Créé automatiquement
// à la première sauvegarde.
export const dataFileName = "ProjectTracker.json";
