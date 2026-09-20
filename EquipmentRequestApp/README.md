# Demandes de matériel — app iOS

Application iOS (SwiftUI) pour **valider les demandes de matériel** soumises
par les employés de la société, actuellement via un mail structuré traité par
un flux **Power Automate** qui alimente le tableau `Demandes_Materiel` du
classeur Excel `Suivi_Demandes_Materiel_SIS2B.xlsx` sur **OneDrive /
SharePoint**.

Rôle principal de l'app : vous (le valideur) consultez la liste des demandes
en attente, et pour chacune :

- **Valider** → l'app écrit le statut `Traité` dans le tableau Excel, génère un
  **PDF** récapitulant la demande (avec zone de signature), puis ouvre une
  fenêtre **Mail** pré-remplie (destinataire = bénéficiaire, copie =
  demandeur + vous, PDF en pièce jointe) pour l'envoyer signer ;
- **Refuser** → l'app écrit le statut `Refusée` dans Excel, sans PDF ni mail.

L'app permet aussi, en secondaire, d'ajouter vous-même une demande
directement (déjà marquée `Traité` à la création) — utile si une demande vous
arrive par un autre canal (oral, téléphone...).

L'app ne fait rien "en silence" : la validation écrit dans Excel, mais
l'envoi du mail reste une action manuelle (vous cliquez sur "Envoyer" dans la
feuille Mail qui s'ouvre déjà remplie).

Cette app est mono-utilisateur côté validation : une seule personne (vous)
valide les demandes depuis l'app. Les employés, eux, n'ont pas besoin de
cette app : ils utilisent le circuit existant (mail structuré → Power
Automate → Excel).

## Comment ça s'articule avec le circuit existant

```
Employé          Mail structuré        Power Automate        Excel (OneDrive)          App iOS (vous)
-------          --------------        --------------        ----------------          ---------------
Envoie un   ---> "Clé=valeur|..."  --> Parse le mail    ---> Nouvelle ligne dans   ---> Onglet "À valider"
mail selon       dans le corps          et ajoute une         Demandes_Materiel,         liste la ligne
le format                              ligne au tableau       colonne Statut vide         (statut vide)
attendu                                                       ("en attente")
                                                                                          Vous appuyez sur
                                                                                          Valider ou Refuser
                                                                Colonne Statut mise  <---
                                                                à jour ("Traité" /
                                                                "Refusée")
```

L'app ne remplace pas ce circuit existant : elle se branche dessus en lisant
et en mettant à jour le même tableau Excel. Si votre flux Power Automate
change, seuls les noms de colonnes doivent rester cohérents avec ceux listés
ci-dessous (l'app les identifie par nom, pas par position).

## Prérequis

- Un Mac avec **Xcode 15+** (nécessaire pour compiler une app iOS — impossible
  depuis Linux/Windows).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) pour générer le projet
  `.xcodeproj` à partir de `project.yml` (évite de committer un fichier de
  projet Xcode binaire fragile) :
  ```bash
  brew install xcodegen
  ```
- Un compte Microsoft 365 (OneDrive Entreprise ou SharePoint) avec les droits
  pour créer une inscription d'application dans Azure AD (ou demandez à votre
  administrateur IT de le faire pour vous — voir étape 1).

## 1. Créer l'inscription d'application Azure AD

L'app se connecte à Microsoft Graph pour lire/écrire le fichier Excel. Il faut
déclarer l'app dans Azure Portal :

1. Allez sur [portal.azure.com](https://portal.azure.com) → **Azure Active
   Directory** (ou **Microsoft Entra ID**) → **Inscriptions d'applications** →
   **Nouvelle inscription**.
2. Nom : `Demandes Matériel iOS` (libre).
3. Types de comptes pris en charge : selon votre organisation (généralement
   "Comptes dans cet annuaire organisationnel uniquement").
4. Ne renseignez pas d'URI de redirection ici, on l'ajoute après.
5. Une fois créée, notez :
   - **Application (client) ID**
   - **Directory (tenant) ID**
6. Dans le menu de l'app → **Authentification** → **Ajouter une plateforme** →
   **iOS/macOS** :
   - Bundle ID : `com.example.EquipmentRequestApp` (ou votre propre bundle ID
     si vous l'avez changé dans `project.yml`, `Info.plist` et les
     entitlements — gardez les trois cohérents).
   - Cela génère automatiquement l'URI de redirection au format
     `msauth.com.example.EquipmentRequestApp://auth`. Vérifiez qu'elle
     correspond exactement à celle dans `Info.plist`
     (`CFBundleURLTypes`).
7. **API permissions** → **Ajouter une autorisation** → **Microsoft Graph** →
   **Delegated permissions** → ajoutez :
   - `Files.ReadWrite`
   - `Sites.ReadWrite.All` (nécessaire seulement si le fichier est sur un site
     SharePoint plutôt que sur le OneDrive personnel de l'utilisateur)
   - `User.Read` (généralement déjà présent par défaut)
   Cliquez ensuite sur **Accorder un consentement administrateur** si demandé
   par votre organisation.
8. **Authentification** → activez **Flux de client public autorisés** (Allow
   public client flows) sur `Yes`.

## 2. Le tableau Excel `Demandes_Materiel`

D'après le fichier `Suivi_Demandes_Materiel_SIS2B.xlsx` déjà en usage :
classeur avec deux feuilles ("Demandes" et "Statistiques"), et un tableau
nommé **`Demandes_Materiel`** sur la feuille "Demandes" avec ces colonnes :

| Colonne Excel | Rôle dans l'app |
|---|---|
| `Reference` | Référence de la demande (ex : objet du mail reçu), affichée dans le détail et le PDF |
| `Date` | Date de la demande |
| `Groupement` | Service/groupement du demandeur, affiché dans le détail et le PDF |
| `Nom_Demandeur` | Nom du demandeur |
| `Mail_Demandeur` | Email du demandeur (copie du mail envoyé) |
| `Pour_Qui` | Nom du bénéficiaire |
| `Telephone` | Téléphone (affiché dans le détail et le PDF) |
| `Materiel` | Type de matériel demandé |
| `Logiciels` | Logiciels associés, affichés dans le détail et le PDF |
| `Opportunite` | Référence commerciale/projet associée, affichée dans le détail et le PDF |
| `Statut` | **En attente** / **En cours** / **Traité** / **Refusée** — mise à jour par l'app |
| `Date_Reception` | Non modifiée par l'app (réservée à un usage manuel ou futur) |
| `Observations` | Utilisé comme justification de la demande, affichée dans le détail et le PDF |

L'app identifie chaque colonne par son **intitulé exact** ci-dessus, avec
quelques synonymes acceptés en secours (insensible à la casse et aux
accents) — voir `Sources/EquipmentRequestApp/Models/ColumnMap.swift` pour la
liste complète. Des colonnes supplémentaires ne posent aucun problème,
l'app les ignore simplement.

### ⚠️ Colonne manquante à ajouter : `Mail_Pour_Qui`

Le tableau actuel ne contient **pas** l'email du bénéficiaire (`Pour_Qui`
n'est qu'un nom), pourtant nécessaire pour lui envoyer le PDF à signer.
Deux choses à faire :

1. **Ajoutez une colonne `Mail_Pour_Qui`** au tableau Excel (et si possible
   au flux Power Automate / format de mail attendu, pour qu'elle soit
   renseignée automatiquement pour les nouvelles demandes).
2. En attendant (ou pour les lignes créées avant cet ajout), l'écran de
   validation de l'app affiche un champ **email du bénéficiaire éditable**,
   pré-rempli si la colonne existe et est renseignée, modifiable sinon. La
   valeur saisie est enregistrée dans la colonne `Mail_Pour_Qui` au moment de
   la validation (si la colonne existe).

### Statut : cycle utilisé par l'app

La feuille "Statistiques" du classeur montre que la colonne Statut utilise
déjà 3 valeurs (`En attente`, `En cours`, `Traité`). Cette app utilise un
cycle simplifié à la demande :

- Une ligne dont le Statut est vide ou différent de `Traité`/`Refusée` (donc
  y compris `En attente` ou `En cours`) apparaît dans l'onglet **À valider**.
- **Valider** fait passer le Statut directement à **`Traité`** (pas d'étape
  intermédiaire `En cours` déclenchée par l'app).
- **Refuser** fait passer le Statut à **`Refusée`** (valeur ajoutée par cette
  app ; elle n'apparaît pas dans les compteurs existants de la feuille
  Statistiques, mais ne les perturbe pas non plus).

### Chemin du fichier

Notez le chemin du fichier tel qu'il apparaît dans le lecteur OneDrive/
SharePoint (relatif à la racine du lecteur), par exemple
`Suivi_Demandes_Materiel_SIS2B.xlsx` s'il est à la racine, ou
`Dossier/Suivi_Demandes_Materiel_SIS2B.xlsx` sinon.

- Si le fichier est dans **votre OneDrive personnel/entreprise** :
  laissez `driveBasePath` = `/me/drive` dans les Réglages de l'app (valeur
  par défaut).
- Si le fichier est sur un **site SharePoint** : il faut utiliser
  `/sites/{site-id}/drive` comme `driveBasePath`. Pour trouver le
  `site-id`, appelez (avec un compte ayant accès, via
  [Graph Explorer](https://developer.microsoft.com/graph/graph-explorer)) :
  `GET https://graph.microsoft.com/v1.0/sites/{hostname}:/sites/{nom-du-site}`
  et récupérez le champ `id`.

## 3. Générer et ouvrir le projet Xcode

```bash
cd EquipmentRequestApp
xcodegen generate
open EquipmentRequestApp.xcodeproj
```

Dans Xcode :

1. Sélectionnez le projet → cible `EquipmentRequestApp` → onglet *Signing &
   Capabilities* → choisissez votre équipe de développement (Apple ID
   personnel ou compte développeur) pour la signature automatique.
2. Si vous changez le bundle identifier, mettez-le à jour à trois endroits :
   `project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`), `Info.plist`
   (`CFBundleURLTypes` → scheme `msauth.<bundle-id>`), et l'inscription Azure
   AD (nouvelle plateforme iOS/macOS avec le nouveau bundle ID).
3. Branchez un iPhone (ou utilisez le simulateur — mais l'envoi de mail réel
   nécessite un compte Mail configuré, donc un appareil physique est
   recommandé pour tester le flux complet) et lancez (`Cmd+R`).

## 4. Configurer l'app au premier lancement

Dans l'onglet **Réglages** de l'app (les valeurs par défaut correspondent déjà
au fichier SIS2B) :

1. **Client ID** et **Tenant ID** : collez les valeurs notées à l'étape 1.
2. **Base du lecteur**, **chemin du fichier .xlsx**, **nom du tableau** :
   valeurs de l'étape 2 (`Demandes_Materiel` est déjà le nom par défaut).
3. **Votre nom** / **Votre email** : utilisés en copie du mail envoyé et comme
   destinataire indiqué pour le retour du document signé.
4. Bouton **Se connecter à Microsoft 365** : une fenêtre de connexion
   Microsoft s'ouvre (Safari intégré). Connectez-vous avec le compte qui a
   accès au fichier Excel.

## 5. Utiliser l'app

1. Onglet **À valider** (écran principal) : liste toutes les lignes du
   tableau Excel dont le statut n'est ni `Traité` ni `Refusée`. Tirez vers
   le bas pour rafraîchir après qu'une nouvelle demande est arrivée.
2. Touchez une demande pour voir son détail (demandeur, bénéficiaire,
   matériel, logiciels, groupement, opportunité, observations...), vérifiez/
   complétez l'**email du bénéficiaire** si besoin, puis :
   - **Valider la demande** → l'app écrit `Traité` dans Excel (et l'email
     bénéficiaire s'il a été saisi), génère le PDF, puis ouvre la feuille
     **Mail** pré-remplie (PDF en pièce jointe, adressée au bénéficiaire,
     avec le demandeur et vous en copie). Vérifiez et appuyez sur **Envoyer**.
   - **Refuser la demande** → confirmation, puis l'app écrit `Refusée` dans
     Excel. Aucun mail n'est envoyé.
3. Le bénéficiaire signe le PDF reçu (à la main après impression, ou en
   l'annotant directement dans l'app Mail/Fichiers avec l'outil Marqueur) et
   vous le renvoie par retour de mail.
4. Onglet **Ajouter** : pour saisir vous-même une demande reçue par un autre
   canal (elle est directement enregistrée comme `Traité`). Ce formulaire
   simplifié ne couvre que demandeur/bénéficiaire/matériel/justification —
   les champs Groupement/Téléphone/Logiciels/Opportunité restent vides pour
   ces demandes.
5. Onglet **Historique** : liste toutes les demandes (en attente, en cours,
   traitées, refusées) avec leur statut, relues directement depuis le tableau
   Excel.

## Notes techniques

- Aucun backend n'est nécessaire : l'app appelle directement l'API Microsoft
  Graph (`workbook/tables/...`) pour lire et écrire dans le classeur Excel
  tel quel — le fichier reste ouvrable normalement dans Excel/Office en ligne,
  et continue d'être alimenté par le flux Power Automate existant.
- Les colonnes sont identifiées par leur **nom d'en-tête**, pas par position :
  l'app est donc tolérante à l'ordre des colonnes et aux colonnes
  supplémentaires.
- Mettre à jour une ligne (validation/refus) renvoie l'intégralité de ses
  valeurs à Microsoft Graph (colonnes Statut et, le cas échéant,
  Mail_Pour_Qui modifiées, le reste inchangé), afin de ne perdre aucune
  donnée écrite par le flux Power Automate.
- L'authentification utilise [MSAL pour iOS](https://github.com/AzureAD/microsoft-authentication-library-for-objc),
  la librairie officielle Microsoft, installée via Swift Package Manager
  (déclarée dans `project.yml`).
- Le PDF est généré nativement avec `UIGraphicsPDFRenderer` (PDFKit), aucune
  dépendance externe.
- L'envoi de mail utilise `MFMailComposeViewController` : il utilise le compte
  Mail déjà configuré sur l'iPhone (Exchange, iCloud, Gmail…), aucune
  configuration SMTP supplémentaire n'est nécessaire côté app. Si aucun
  compte Mail n'est configuré sur l'appareil, l'app avertit que la demande a
  bien été validée dans Excel mais qu'il faudra renvoyer le PDF manuellement.

## Limites connues / pistes d'amélioration

- Un seul valideur : pour permettre à plusieurs personnes de valider depuis
  l'app, il faudrait ajouter une notion de rôle/compte (actuellement tout
  utilisateur connecté avec les bons droits Graph peut valider).
- La colonne `Mail_Pour_Qui` n'existe pas encore dans le tableau réel — voir
  la section 2 ci-dessus. Tant qu'elle n'est pas ajoutée, l'app fonctionne
  quand même grâce au champ email éditable, mais rien n'est pré-rempli
  automatiquement pour les nouvelles demandes.
- Le statut `En cours` existant dans le tableau n'est pas utilisé par l'app
  (qui passe directement de `En attente` à `Traité`) ; si ce statut
  intermédiaire doit être piloté depuis l'app plus tard, il faudra ajouter un
  bouton "Marquer comme en cours" séparé.
- `Date_Reception` n'est pas renseigné par l'app : le retour du PDF signé se
  fait par mail classique et n'est pas réimporté automatiquement dans Excel.
- Pas de notification push quand une nouvelle demande arrive : il faut ouvrir
  l'app et tirer pour rafraîchir l'onglet "À valider".
- L'icône d'application (`AppIcon.appiconset`) est vide : ajoutez une image
  1024×1024 avant une éventuelle publication sur l'App Store.
- La mise à jour de statut appelle
  `PATCH /workbook/tables/{table}/rows/itemAt(index=N)` avec les valeurs
  complètes de la ligne. Ce comportement est basé sur la documentation
  officielle de l'API Excel de Microsoft Graph ; vérifiez-le en conditions
  réelles (Graph Explorer ou test sur device) lors du premier déploiement,
  l'API Graph évoluant parfois.
