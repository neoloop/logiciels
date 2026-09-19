# Demandes de matériel — app iOS

Application iOS (SwiftUI) qui permet de saisir une demande de matériel
(ordinateur portable/fixe, téléphone, clé USB, autre), de la valider, puis
automatiquement :

1. d'ajouter une ligne dans un tableau Excel stocké sur **OneDrive / SharePoint**
   (via l'API Microsoft Graph, sans backend à héberger) ;
2. de générer un **PDF** récapitulant la demande, avec une zone de signature ;
3. d'ouvrir une fenêtre **Mail** pré-remplie (destinataire, sujet, corps, PDF en
   pièce jointe) pour envoyer le PDF au bénéficiaire, qui le signe et le renvoie.

L'app ne fait rien "en silence" : la validation écrit dans Excel, mais l'envoi
du mail reste une action manuelle (l'utilisateur clique sur "Envoyer" dans la
feuille Mail qui s'ouvre déjà remplie).

Cette app est mono-utilisateur côté validation : une seule personne (vous)
valide les demandes depuis l'app.

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

## 2. Préparer le fichier Excel

1. Créez (ou choisissez) un fichier `.xlsx` sur OneDrive ou dans une
   bibliothèque de documents SharePoint, par exemple :
   `Demandes/DemandesMateriel.xlsx`.
2. Sur la première feuille, créez un **tableau** (onglet *Insertion* >
   *Tableau*) avec exactement ces en-têtes de colonnes, dans cet ordre :

   | Date | Demandeur | Email demandeur | Bénéficiaire | Email bénéficiaire | Matériel | Justification | Statut |
   |------|-----------|------------------|--------------|---------------------|----------|----------------|--------|

3. Nommez ce tableau (sélectionner le tableau → onglet *Tableau* > *Nom du
   tableau*), par exemple `DemandesMateriel`. C'est ce nom qu'il faudra
   renseigner dans les Réglages de l'app.
4. Notez le chemin du fichier tel qu'il apparaît dans le lecteur (relatif à la
   racine du lecteur), par exemple `Demandes/DemandesMateriel.xlsx`.

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

Dans l'onglet **Réglages** de l'app :

1. **Client ID** et **Tenant ID** : collez les valeurs notées à l'étape 1.
2. **Base du lecteur**, **chemin du fichier .xlsx**, **nom du tableau** :
   valeurs de l'étape 2.
3. **Votre nom** / **Votre email** : utilisés en copie du mail envoyé et comme
   destinataire indiqué pour le retour du document signé.
4. Bouton **Se connecter à Microsoft 365** : une fenêtre de connexion
   Microsoft s'ouvre (Safari intégré). Connectez-vous avec le compte qui a
   accès au fichier Excel.

## 5. Utiliser l'app

1. Onglet **Nouvelle demande** : renseignez le demandeur, le bénéficiaire,
   le type de matériel et la justification, puis **Continuer**.
2. Écran de vérification : relisez, puis **Valider la demande**.
   - L'app se connecte à Microsoft Graph (silencieusement si déjà connecté),
     ajoute une ligne au tableau Excel, génère le PDF.
   - La feuille **Mail** s'ouvre, pré-remplie avec le PDF en pièce jointe,
     adressée au bénéficiaire (avec le demandeur et vous en copie). Vérifiez
     et appuyez sur **Envoyer**.
3. Le bénéficiaire signe le PDF (à la main après impression, ou en l'annotant
   directement dans l'app Mail/Fichiers avec l'outil Marqueur) et vous le
   renvoie par retour de mail.
4. Onglet **Historique** : liste les demandes déjà enregistrées, relues
   directement depuis le tableau Excel (tirez vers le bas pour rafraîchir).

## Notes techniques

- Aucun backend n'est nécessaire : l'app appelle directement l'API Microsoft
  Graph (`workbook/tables/.../rows/add`) pour écrire dans le classeur Excel
  tel quel — le fichier reste ouvrable normalement dans Excel/Office en ligne.
- L'authentification utilise [MSAL pour iOS](https://github.com/AzureAD/microsoft-authentication-library-for-objc),
  la librairie officielle Microsoft, installée via Swift Package Manager
  (déclarée dans `project.yml`).
- Le PDF est généré nativement avec `UIGraphicsPDFRenderer` (PDFKit), aucune
  dépendance externe.
- L'envoi de mail utilise `MFMailComposeViewController` : il utilise le compte
  Mail déjà configuré sur l'iPhone (Exchange, iCloud, Gmail…), aucune
  configuration SMTP supplémentaire n'est nécessaire côté app. Si aucun
  compte Mail n'est configuré sur l'appareil, l'app avertit que la demande a
  bien été enregistrée dans Excel mais qu'il faudra renvoyer le PDF
  manuellement.

## Limites connues / pistes d'amélioration

- Un seul valideur : pour permettre à plusieurs personnes de valider depuis
  l'app, il faudrait ajouter une notion de rôle/compte (actuellement tout
  utilisateur connecté avec les bons droits Graph peut valider).
- Pas de suivi de statut "signé/retourné" : le retour du PDF signé se fait
  par mail classique, il n'est pas réimporté automatiquement dans Excel. Cela
  pourrait être ajouté en écoutant les mails entrants (ex: via Microsoft
  Graph `mail` API) ou en ajoutant un champ "Statut" à cocher manuellement.
- L'icône d'application (`AppIcon.appiconset`) est vide : ajoutez une image
  1024×1024 avant une éventuelle publication sur l'App Store.
