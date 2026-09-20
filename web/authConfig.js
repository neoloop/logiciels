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

// Chemin (depuis la racine OneDrive) vers le classeur partagé avec l'app iOS.
export const workbookPath = "/me/drive/root:/ProjectTracker.xlsx:/workbook";
