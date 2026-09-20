# Suivi de projets

Application de suivi de projets : créez un projet avec date de début/fin (la
durée en jours est calculée automatiquement), ajoutez ses étapes (à faire /
en cours / fait), et visualisez tout sur un diagramme de Gantt annuel.

Deux clients, une seule source de données :

- **`ios/`** — app iOS native (SwiftUI), connexion à votre compte Microsoft.
- **`web/`** — page web à héberger sur GitHub Pages, pour gérer vos projets
  depuis un navigateur.

Les deux lisent/écrivent directement dans un classeur **Excel sur OneDrive**
(`ProjectTracker.xlsx`) via l'API Microsoft Graph — pas de serveur ni de base
de données séparée.

Pour tout configurer (classeur Excel, inscription Azure AD, projet Xcode,
GitHub Pages), suivez **[`docs/SETUP.md`](docs/SETUP.md)**.
