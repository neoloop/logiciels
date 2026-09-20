# App iOS — Suivi de projets

Ce dossier contient le **code source Swift** de l'application, prêt à être
glissé dans un projet Xcode. Il n'y a volontairement pas de `.xcodeproj` ici
(ces fichiers sont fragiles à générer à la main) — vous le créez en 2 minutes
dans Xcode, puis vous y ajoutez ces fichiers.

Suivez `../docs/SETUP.md`, section « App iOS », pour :
1. Créer le projet Xcode et lui ajouter ces fichiers.
2. Ajouter le SDK MSAL (Microsoft Authentication Library) via Swift Package Manager.
3. Renseigner `ProjectTracker/Services/AuthConfig.swift` avec l'identifiant
   d'application créé sur le portail Azure.
4. Configurer le schéma d'URL de redirection dans `Info.plist`.

## Structure

```
ProjectTracker/
├── ProjectTrackerApp.swift        point d'entrée
├── Models/                        Project, ProjectTask, TaskStatus
├── Services/
│   ├── AuthConfig.swift           clientId / redirectUri à renseigner
│   ├── AuthManager.swift          connexion Microsoft (MSAL)
│   ├── GraphExcelService.swift    lecture/écriture des tables Excel via Graph
│   └── ProjectStore.swift         cache local + synchronisation
└── Views/                         écrans SwiftUI
```

⚠️ Ce code n'a pas pu être compilé dans cet environnement (pas de macOS/Xcode
disponible ici) : ouvrez-le dans Xcode et corrigez les éventuels ajustements
mineurs d'API (une méthode MSAL renommée entre deux versions, par exemple)
avant la première exécution sur votre iPhone.
