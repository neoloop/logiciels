# Mise en place — Suivi de projets (iOS + web + Excel/OneDrive)

Ce document explique comment brancher les deux applications (app iOS et page
web) sur un même classeur Excel stocké sur votre OneDrive, qui sert de base
de données partagée. Aucun serveur n'est nécessaire : les deux apps parlent
directement à Excel via l'API Microsoft Graph.

**Important : héberger une page HTML interactive directement "sur OneDrive"
ne fonctionne pas** — quand OneDrive affiche un fichier `.html`, il en montre
un aperçu (ou le code source), il n'exécute pas le JavaScript qu'il contient,
pour des raisons de sécurité. La page de ce projet est donc hébergée
gratuitement sur **GitHub Pages** (le dépôt Git qui contient ce code) ; elle
lit et écrit malgré tout dans le fichier Excel qui, lui, reste bien sur votre
OneDrive. Le résultat pour vous est le même : une page web qui gère vos
projets, avec les données dans un vrai fichier Excel dans votre OneDrive.

## Vue d'ensemble

```
 App iOS (Swift/MSAL) ──┐
                         ├──►  Microsoft Graph API  ──►  ProjectTracker.xlsx (sur votre OneDrive)
 Page web (GitHub Pages)┘
```

Les deux clients lisent/écrivent directement les tableaux Excel « Projects »
et « Tasks » du classeur. Il n'y a pas de synchronisation différée : chaque
création/modification/suppression écrit immédiatement dans Excel.

## Étape 1 — Créer le classeur Excel sur OneDrive

1. Sur [onedrive.com](https://onedrive.live.com), créez un nouveau classeur
   Excel **à la racine** de votre OneDrive, nommé exactement `ProjectTracker.xlsx`.
   (Si vous préférez le mettre dans un sous-dossier, adaptez le chemin
   `workbookPath` dans `ios/ProjectTracker/Services/AuthConfig.swift` et
   `web/authConfig.js`, par ex. `/me/drive/root:/Documents/ProjectTracker.xlsx:/workbook`.)
2. Renommez la première feuille `Projects`. Dans la ligne 1, entrez ces
   en-têtes de colonnes, dans cet ordre :
   `ID | Nom | DateDebut | DateFin | DureeJours | Notes`
3. **Sélectionnez les colonnes `DateDebut` et `DateFin`, clic droit → Format de
   cellule → Texte.** C'est important : sans ça, Excel convertit
   automatiquement les dates que les apps écrivent en numéros de série, ce
   qui reste géré par le code mais est plus fragile.
4. Sélectionnez la plage des en-têtes (A1:F1), puis **Insertion → Tableau**
   (cochez « Mon tableau comporte des en-têtes »).
5. Cliquez sur le tableau, onglet **Création de tableau**, et renommez-le
   (champ « Nom du tableau ») en exactement **`Projects`**.
6. Ajoutez une deuxième feuille nommée `Tasks`, avec les en-têtes :
   `ID | ProjetID | Nom | Statut | Ordre`
7. Convertissez-la aussi en tableau nommé exactement **`Tasks`**.
8. Enregistrez le classeur.

Les deux apps génèrent elles-mêmes les valeurs de la colonne `ID` (un
identifiant unique) et calculent `DureeJours` — vous n'avez rien à saisir à
la main dans Excel, ce fichier n'est là que comme entrepôt de données (et
pour que vous puissiez, si vous voulez, faire vos propres tableaux croisés
ou graphiques dessus).

## Étape 2 — Créer l'application Azure AD (une seule pour les deux clients)

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
     Pages sera servie (voir étape 4), par ex.
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

## Étape 3 — App iOS

Voir `ios/README.md` pour la structure des fichiers. En résumé :

1. Dans Xcode : **File → New → Project → iOS → App**, SwiftUI, nommez-le
   `ProjectTracker`, bundle identifier = celui utilisé à l'étape 2.
2. Supprimez le `ContentView.swift` généré par défaut, puis glissez tout le
   contenu de `ios/ProjectTracker/` (Models, Services, Views,
   `ProjectTrackerApp.swift`) dans le projet Xcode.
3. **File → Add Package Dependencies…**, ajoutez
   `https://github.com/AzureAD/microsoft-authentication-library-for-objc`
   (le SDK MSAL), produit `MSAL`.
4. Ouvrez `ProjectTracker/Services/AuthConfig.swift` et renseignez :
   - `clientId` = l'ID d'application noté à l'étape 2.
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

## Étape 4 — Page web (hébergée sur GitHub Pages)

1. Dans les réglages du dépôt GitHub → **Pages** → Source = la branche de ce
   code, dossier **`/web`** (ou déployez juste le contenu du dossier `web/`
   à la racine d'un autre dépôt/branche si vous préférez).
2. Notez l'URL générée (affichée dans les réglages Pages une fois activée).
3. Retournez sur le portail Azure (étape 2.5) et mettez à jour l'URI de
   redirection SPA pour qu'elle corresponde exactement à cette URL.
4. Ouvrez `web/authConfig.js` et renseignez `clientId` avec l'ID
   d'application de l'étape 2.
5. Poussez ces changements ; GitHub Pages republie automatiquement.
6. Ouvrez l'URL sur votre téléphone ou ordinateur, connectez-vous avec
   Microsoft : vous gérez vos projets, et tout part dans le même classeur
   Excel que l'app iOS.

## Comment les données sont stockées

| Table Excel | Colonnes |
|---|---|
| `Projects` | ID, Nom, DateDebut, DateFin, DureeJours, Notes |
| `Tasks` | ID, ProjetID, Nom, Statut, Ordre |

`Statut` vaut toujours l'une de ces trois valeurs : `À faire`, `En cours`,
`Fait`. `DureeJours` est recalculée par les apps à chaque enregistrement
(nombre de jours inclusif entre début et fin).

## Le diagramme annuel

Les deux apps affichent, pour une année sélectionnée, une frise horizontale
par projet (barre allant de la date de début à la date de fin), avec une
partie remplie proportionnelle au pourcentage d'étapes marquées « Fait »
(vert plein quand le projet est à 100 %), et un repère vertical sur la date
du jour.
