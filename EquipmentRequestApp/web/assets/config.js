// Configuration à modifier avant de déployer ces pages (voir web/README.md).
// Les deux pages (nouvelle-demande.html et valider.html) partagent ce fichier.
window.APP_CONFIG = {
  // Application (client) ID de l'inscription Azure AD — la même que celle
  // utilisée par l'app iOS (une inscription peut avoir plusieurs plateformes).
  clientId: "REMPLACER-PAR-VOTRE-CLIENT-ID",

  // Directory (tenant) ID Azure AD (ou "organizations").
  tenantId: "REMPLACER-PAR-VOTRE-TENANT-ID",

  // Base du chemin Graph vers le lecteur : "/me/drive" pour un OneDrive
  // personnel/entreprise, ou "/sites/{site-id}/drive" pour un site SharePoint.
  driveBasePath: "/me/drive",

  // Chemin du fichier JSON dans le lecteur — le même que celui configuré
  // dans l'app iOS (Réglages > Fichier des demandes).
  jsonFilePath: "Suivi_Demandes_Materiel_SIS2B.json",

  // Email et nom du valideur : mis en copie du mail envoyé depuis la page
  // "Valider les demandes", et indiqués comme destinataire du retour signé.
  validatorEmail: "",
  validatorName: "",
};

// URI de redirection MSAL : calculée automatiquement à partir de l'URL réelle
// de la page (utile car les deux pages ont des URLs différentes). Elle doit
// être déclarée telle quelle dans Azure AD (plateforme "Application
// monopage (SPA)") — voir web/README.md.
window.APP_CONFIG.redirectUri = window.location.origin + window.location.pathname;
