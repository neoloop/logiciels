# Demandes de matériel — app iOS

Application iOS (SwiftUI) pour **valider les demandes de matériel** soumises
par les employés de la société, aux côtés de deux pages web (voir
[`../web/README.md`](../web/README.md)) qui permettent de soumettre et de
consulter/valider les demandes depuis un navigateur.

Les trois s'appuient sur **une seule source de vérité** : un fichier **JSON**
stocké sur **OneDrive/SharePoint**, lu et écrit via Microsoft Graph — pas de
backend à héberger.

Rôle principal de l'app iOS : vous (le valideur) consultez la liste des
demandes en attente, et pour chacune :

- **Valider** → l'app écrit le statut `Traité` dans le JSON, génère un
  **PDF** récapitulant la demande (avec zone de signature), puis ouvre une
  fenêtre **Mail** pré-remplie (destinataire = bénéficiaire, copie =
  demandeur + vous, PDF en pièce jointe) pour l'envoyer signer ;
- **Refuser** → l'app écrit le statut `Refusée` dans le JSON, sans PDF ni mail.

L'app permet aussi, en secondaire, d'ajouter vous-même une demande
directement (déjà marquée `Traité` à la création) — utile si une demande vous
arrive par un autre canal (oral, téléphone...).

L'app ne fait rien "en silence" : la validation écrit dans le JSON, mais
l'envoi du mail reste une action manuelle (vous cliquez sur "Envoyer" dans la
feuille Mail qui s'ouvre déjà remplie). La page web équivalente
(`valider.html`) envoie le mail directement via Microsoft Graph, un
navigateur ne pouvant pas ouvrir de fenêtre Mail native pré-remplie avec
pièce jointe — voir `web/README.md`.

Cette app est mono-utilisateur côté validation : une seule personne (vous)
valide les demandes depuis l'app ou la page web équivalente.

## Comment ça s'articule avec les pages web et le fichier JSON

```
Employé                          Page web                    Fichier JSON               App iOS (vous) ou
                                  "Nouvelle demande"           (OneDrive/SharePoint)       page web "Valider"
--------                         ------------------            ---------------------      -------------------
Remplit le formulaire     --->   Ajoute une entrée       --->  Nouvelle demande,     --->  Liste "À valider"
sur son navigateur                au JSON via Graph             statut "En attente"         affiche la demande

                                                                                             Valider ou Refuser
                                                                Statut mis à jour      <---  (PDF + mail si
                                                                ("Traité"/"Refusée")          validé)
```

Le fichier JSON remplace l'ancien tableau Excel (`Demandes_Materiel`) utilisé
précédemment : plus besoin de correspondance par nom de colonne, tout est
directement typé. Un même fichier peut être modifié indifféremment par l'app
iOS ou l'une des deux pages web ; un ETag protège contre les écritures
concurrentes (si deux personnes valident au même moment, la seconde écriture
échoue proprement et invite à recharger plutôt que d'écraser la première).

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

L'app (et les pages web) se connectent à Microsoft Graph pour lire/écrire le
fichier JSON. Une **seule** inscription Azure AD suffit pour l'app iOS et les
pages web (elle peut porter plusieurs plateformes : iOS et Application
monopage/SPA).

1. Allez sur [portal.azure.com](https://portal.azure.com) → **Azure Active
   Directory** (ou **Microsoft Entra ID**) → **Inscriptions d'applications** →
   **Nouvelle inscription**.
2. Nom : `Demandes Matériel` (libre).
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
7. Toujours dans **Authentification** → **Ajouter une plateforme** →
   **Application monopage (SPA)** : ajoutez l'URL exacte de chacune des deux
   pages web une fois déployées sur votre NAS (ex :
   `https://nas.exemple.local:5001/nouvelle-demande.html` et
   `.../valider.html`) — voir `web/README.md` pour le détail complet de
   cette étape (nécessite une adresse HTTPS, même en local).
8. **API permissions** → **Ajouter une autorisation** → **Microsoft Graph** →
   **Delegated permissions** → ajoutez :
   - `Files.ReadWrite`
   - `Sites.ReadWrite.All` (nécessaire seulement si le fichier est sur un site
     SharePoint plutôt que sur le OneDrive personnel de l'utilisateur)
   - `Mail.Send` (nécessaire uniquement pour la page web `valider.html`, qui
     envoie le mail via Graph — l'app iOS utilise l'app Mail locale et n'en a
     pas besoin, mais l'ajouter ne gêne pas)
   - `User.Read` (généralement déjà présent par défaut)
   Cliquez ensuite sur **Accorder un consentement administrateur** si demandé
   par votre organisation.
9. **Authentification** → activez **Flux de client public autorisés** (Allow
   public client flows) sur `Yes`.

## 2. Le fichier JSON des demandes

Le fichier (ex : `Suivi_Demandes_Materiel_SIS2B.json`) contient un objet avec
un tableau `requests`, chaque demande ayant ces champs :

```json
{
  "schemaVersion": 1,
  "requests": [
    {
      "id": "identifiant unique (UUID)",
      "reference": "référence libre (optionnelle)",
      "date": "20/09/2026",
      "groupement": "service/groupement du demandeur",
      "requesterName": "nom du demandeur",
      "requesterEmail": "email du demandeur",
      "beneficiaryName": "nom du bénéficiaire",
      "beneficiaryEmail": "email du bénéficiaire",
      "phone": "téléphone de contact",
      "equipment": "type de matériel demandé",
      "software": "logiciels nécessaires",
      "opportunity": "référence commerciale/projet associée",
      "justification": "justification de la demande",
      "status": "En attente | En cours | Traité | Refusée",
      "receptionDate": "réservé, non utilisé par l'app pour l'instant"
    }
  ]
}
```

Il n'y a rien à créer manuellement : si le fichier n'existe pas encore à
l'emplacement configuré, l'app iOS et les pages web le créent automatiquement
lors du premier enregistrement.

### Statut : cycle utilisé par l'app et les pages web

- Une demande dont le statut est vide ou différent de `Traité`/`Refusée`
  (donc y compris `En attente` ou `En cours`) apparaît dans la liste
  **À valider**.
- **Valider** fait passer le statut directement à **`Traité`** (pas d'étape
  intermédiaire `En cours` déclenchée automatiquement).
- **Refuser** fait passer le statut à **`Refusée`**.

### Chemin du fichier

Notez le chemin du fichier tel qu'il apparaît dans le lecteur OneDrive/
SharePoint (relatif à la racine du lecteur), par exemple
`Suivi_Demandes_Materiel_SIS2B.json` s'il est à la racine, ou
`Dossier/Suivi_Demandes_Materiel_SIS2B.json` sinon. **Ce doit être exactement
le même chemin** dans les Réglages de l'app iOS et dans `web/assets/config.js`
des deux pages web.

- Si le fichier est dans **votre OneDrive personnel/entreprise** :
  laissez `driveBasePath` = `/me/drive` (valeur par défaut).
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
2. **Base du lecteur** et **chemin du fichier .json** : valeurs de l'étape 2.
3. **Votre nom** / **Votre email** : utilisés en copie du mail envoyé et comme
   destinataire indiqué pour le retour du document signé.
4. Bouton **Se connecter à Microsoft 365** : une fenêtre de connexion
   Microsoft s'ouvre (Safari intégré). Connectez-vous avec le compte qui a
   accès au fichier.

## 5. Utiliser l'app

1. Onglet **À valider** (écran principal) : liste toutes les demandes dont le
   statut n'est ni `Traité` ni `Refusée`. Tirez vers le bas pour rafraîchir
   après qu'une nouvelle demande est arrivée (via la page web ou un autre
   moyen).
2. Touchez une demande pour voir son détail (demandeur, bénéficiaire,
   matériel, logiciels, groupement, opportunité, observations...), vérifiez/
   complétez l'**email du bénéficiaire** si besoin, puis :
   - **Valider la demande** → l'app écrit `Traité` dans le JSON (et l'email
     bénéficiaire s'il a été saisi), génère le PDF, puis ouvre la feuille
     **Mail** pré-remplie (PDF en pièce jointe, adressée au bénéficiaire,
     avec le demandeur et vous en copie). Vérifiez et appuyez sur **Envoyer**.
   - **Refuser la demande** → confirmation, puis l'app écrit `Refusée` dans
     le JSON. Aucun mail n'est envoyé.
3. Le bénéficiaire signe le PDF reçu (à la main après impression, ou en
   l'annotant directement dans l'app Mail/Fichiers avec l'outil Marqueur) et
   vous le renvoie par retour de mail.
4. Onglet **Ajouter** : pour saisir vous-même une demande reçue par un autre
   canal (elle est directement enregistrée comme `Traité`). Ce formulaire
   simplifié ne couvre que demandeur/bénéficiaire/matériel/justification —
   les champs Groupement/Téléphone/Logiciels/Opportunité restent vides pour
   ces demandes.
5. Onglet **Historique** : liste toutes les demandes (en attente, en cours,
   traitées, refusées) avec leur statut, relues directement depuis le fichier
   JSON.

## Notes techniques

- Aucun backend n'est nécessaire : l'app appelle directement l'API Microsoft
  Graph (`GET`/`PUT .../content`) pour lire et écrire le fichier JSON tel
  quel sur OneDrive/SharePoint.
- Toute écriture (validation/refus/ajout) renvoie l'intégralité du fichier à
  Microsoft Graph, protégée par un en-tête `If-Match` (ETag) : si le fichier
  a changé entre-temps (autre personne, autre appareil, page web), Graph
  répond 412 et l'app affiche une erreur invitant à recharger plutôt que
  d'écraser silencieusement.
- L'authentification utilise [MSAL pour iOS](https://github.com/AzureAD/microsoft-authentication-library-for-objc),
  la librairie officielle Microsoft, installée via Swift Package Manager
  (déclarée dans `project.yml`).
- Le PDF est généré nativement avec `UIGraphicsPDFRenderer` (PDFKit), aucune
  dépendance externe.
- L'envoi de mail utilise `MFMailComposeViewController` : il utilise le compte
  Mail déjà configuré sur l'iPhone (Exchange, iCloud, Gmail…), aucune
  configuration SMTP supplémentaire n'est nécessaire côté app. Si aucun
  compte Mail n'est configuré sur l'appareil, l'app avertit que la demande a
  bien été validée mais qu'il faudra renvoyer le PDF manuellement.

## Limites connues / pistes d'amélioration

- Un seul valideur : pour permettre à plusieurs personnes de valider depuis
  l'app, il faudrait ajouter une notion de rôle/compte (actuellement tout
  utilisateur connecté avec les bons droits Graph peut valider).
- Le statut `En cours` n'est pas utilisé par l'app (qui passe directement de
  `En attente` à `Traité`) ; si ce statut intermédiaire doit être piloté
  depuis l'app plus tard, il faudra ajouter un bouton "Marquer comme en
  cours" séparé.
- `receptionDate` n'est pas renseigné par l'app : le retour du PDF signé se
  fait par mail classique et n'est pas réimporté automatiquement.
- Pas de notification push quand une nouvelle demande arrive : il faut ouvrir
  l'app et tirer pour rafraîchir l'onglet "À valider".
- L'icône d'application (`AppIcon.appiconset`) est vide : ajoutez une image
  1024×1024 avant une éventuelle publication sur l'App Store.
- Le fichier JSON est réécrit intégralement à chaque modification (pas de
  mise à jour partielle) : au-delà de quelques Mo (plusieurs milliers de
  demandes avec historique complet), il faudrait passer à l'API de session
  d'upload de Microsoft Graph plutôt qu'au simple `PUT .../content` utilisé
  ici — largement suffisant pour l'usage actuel.
