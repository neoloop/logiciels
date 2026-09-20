# Mise en place — Suivi de projets (iOS + web + OneDrive)

Ce document explique comment brancher les deux applications (app iOS et page
web) sur un même fichier stocké sur votre OneDrive, qui sert de base de
données partagée. Aucun serveur n'est nécessaire : les deux apps parlent
directement à OneDrive via l'API Microsoft Graph.

Les données sont stockées dans un simple **fichier JSON**
(`ProjectTracker.json`) plutôt que dans un classeur Excel : le fichier est
créé automatiquement au premier enregistrement, il n'y a rien à préparer sur
OneDrive à l'avance. La visualisation (liste de projets, étapes, diagramme de
Gantt) se fait dans l'app iOS et dans la page web ci-dessous, pas dans Excel.

**Important : héberger une page HTML interactive directement "sur OneDrive"
ne fonctionne pas** — quand OneDrive affiche un fichier `.html`, il en montre
un aperçu (ou le code source), il n'exécute pas le JavaScript qu'il contient,
pour des raisons de sécurité. La page de ce projet est donc hébergée
gratuitement sur **GitHub Pages** (le dépôt Git qui contient ce code) ; elle
lit et écrit malgré tout dans le fichier qui, lui, reste bien sur votre
OneDrive.

## Vue d'ensemble

```
 App iOS (Swift/MSAL) ──┐
                         ├──►  Microsoft Graph API  ──►  ProjectTracker.json (sur votre OneDrive)
 Page web (GitHub Pages)┘
```

Les deux clients téléchargent le fichier JSON entier, le modifient en
mémoire, puis le renvoient en entier à chaque création/modification/
suppression. C'est volontairement simple : adapté à un usage par une
personne, sur un appareil à la fois (pas de fusion en cas d'écriture
simultanée depuis deux appareils au même moment).

## Étape 1 — Créer l'application Azure AD (une seule pour les deux clients)

1. Allez sur [portal.azure.com](https://portal.azure.com) et connectez-vous
   avec le **même compte Microsoft que celui qui possède le OneDrive**
   (un compte personnel gratuit convient, aucun abonnement payant requis
   pour cette étape).
2. Recherchez **« Inscriptions d'applications »** (App registrations) →
   **Nouvelle inscription**.
   - Nom : `Suivi de projets`
   - Types de comptes pris en charge : **« Comptes dans n'importe quel
     annuaire organisationnel et comptes Microsoft personnels »**
   - Laissez l'URI de redirection vide pour l'instant → **Inscrire**.
3. Sur la page de présentation de l'app, notez l'**ID d'application
   (client)** — un GUID. Vous le mettrez dans les deux configs plus bas.
4. Menu **Authentification** → **Ajouter une plateforme** → **iOS / macOS** :
   - Bundle ID : l'identifiant de bundle que vous donnerez à votre app dans
     Xcode (ex. `com.votrenom.ProjectTracker`).
   - Azure génère automatiquement l'URI de redirection, de la forme
     `msauth.com.votrenom.ProjectTracker://auth`. Copiez-la telle quelle.
5. **Ajouter une plateforme** → **Application monopage (SPA)** :
   - URI de redirection : l'adresse exacte à laquelle votre page GitHub
     Pages sera servie (voir étape 3), par ex.
     `https://<votre-compte>.github.io/logiciels/web/`.
     Vérifiez l'URL réellement affichée dans la barre d'adresse une fois la
     page publiée et faites-la correspondre au caractère près.
6. Menu **Autorisations API** → **Ajouter une autorisation** → **Microsoft
   Graph** → **Autorisations déléguées**, cochez `User.Read` et
   `Files.ReadWrite` (et laissez `offline_access`, ajouté par défaut).
   Aucun consentement administrateur n'est nécessaire pour un compte
   personnel.

Aucun secret client n'est nécessaire : les deux apps sont des « clients
publics » (mobile/SPA) qui utilisent PKCE.

## Étape 2 — App iOS

Voir `ios/README.md` pour la structure des fichiers. En résumé :

1. Dans Xcode : **File → New → Project → iOS → App**, SwiftUI, nommez-le
   `ProjectTracker`, bundle identifier = celui utilisé à l'étape 1.
2. Supprimez le `ContentView.swift` généré par défaut, puis glissez tout le
   contenu de `ios/ProjectTracker/` (Models, Services, Views,
   `ProjectTrackerApp.swift`) dans le projet Xcode.
3. **File → Add Package Dependencies…**, ajoutez
   `https://github.com/AzureAD/microsoft-authentication-library-for-objc`
   (le SDK MSAL), produit `MSAL`.
4. Ouvrez `ProjectTracker/Services/AuthConfig.swift` et renseignez :
   - `clientId` = l'ID d'application noté à l'étape 1.
   - `redirectUri` = l'URI `msauth.<bundle id>://auth` générée par Azure.
5. Dans `Info.plist` du projet, ajoutez un **URL Type** dont le schéma est
   `msauth.<bundle id>` (juste le schéma, sans `://auth`), pour que iOS
   redirige vers l'app après la connexion.
6. Compilez sur votre iPhone (câble + Xcode, ou via TestFlight avec un
   compte développeur Apple à 99 $/an si vous voulez l'installer plus de 7
   jours sans recompiler).

Ce code n'a pas pu être compilé dans cet environnement (pas de macOS/Xcode
disponible ici) — attendez-vous à devoir ajuster quelques détails d'API MSAL
mineurs selon la version du SDK que vous installez.

## Étape 3 — Page web (hébergée sur GitHub Pages)

1. Dans les réglages du dépôt GitHub → **Pages** → Source = la branche de ce
   code, dossier **`/web`** (ou déployez juste le contenu du dossier `web/`
   à la racine d'un autre dépôt/branche si vous préférez).
2. Notez l'URL générée (affichée dans les réglages Pages une fois activée).
3. Retournez sur le portail Azure (étape 1.5) et mettez à jour l'URI de
   redirection SPA pour qu'elle corresponde exactement à cette URL.
4. Ouvrez `web/authConfig.js` et renseignez `clientId` avec l'ID
   d'application de l'étape 1.
5. Poussez ces changements ; GitHub Pages republie automatiquement.
6. Ouvrez l'URL sur votre téléphone ou ordinateur, connectez-vous avec
   Microsoft : vous gérez vos projets, et tout part dans le même fichier
   que l'app iOS.

## Comment les données sont stockées

`ProjectTracker.json`, à la racine de votre OneDrive, avec cette forme :

```json
{
  "projects": [
    { "id": "…", "name": "Refonte site web", "startDate": "2026-03-01", "endDate": "2026-04-15", "notes": "" }
  ],
  "tasks": [
    { "id": "…", "projectId": "…", "name": "Maquettes", "status": "Fait", "order": 0 }
  ]
}
```

`status` vaut toujours l'une de ces trois valeurs : `À faire`, `En cours`,
`Fait`. La durée en jours n'est pas stockée : elle est recalculée à
l'affichage (nombre de jours inclusif entre début et fin).

## Le diagramme annuel

Les deux apps affichent, pour une année sélectionnée, une frise horizontale
par projet (barre allant de la date de début à la date de fin), avec une
partie remplie proportionnelle au pourcentage d'étapes marquées « Fait »
(vert plein quand le projet est à 100 %), et un repère vertical sur la date
du jour.
