# Demandes de matériel — app iOS

Application iOS (SwiftUI) pour **valider les demandes de matériel** soumises
par les employés de la société via un formulaire externe (Microsoft Forms,
Power Apps, ou tout autre outil) qui alimente un tableau Excel stocké sur
**OneDrive / SharePoint**.

Rôle principal de l'app : vous (le valideur) consultez la liste des demandes
en attente, et pour chacune :

- **Valider** → l'app met à jour le statut dans le tableau Excel, génère un
  **PDF** récapitulant la demande (avec zone de signature), puis ouvre une
  fenêtre **Mail** pré-remplie (destinataire = bénéficiaire, copie =
  demandeur + vous, PDF en pièce jointe) pour l'envoyer signer ;
- **Refuser** → l'app met juste à jour le statut dans Excel, sans PDF ni mail.

L'app permet aussi, en secondaire, d'ajouter vous-même une demande
directement (déjà validée à la création) — utile si une demande vous arrive
par un autre canal (oral, téléphone...).

L'app ne fait rien "en silence" : la validation écrit dans Excel, mais
l'envoi du mail reste une action manuelle (vous cliquez sur "Envoyer" dans la
feuille Mail qui s'ouvre déjà remplie).

Cette app est mono-utilisateur côté validation : une seule personne (vous)
valide les demandes depuis l'app. Les employés, eux, n'ont pas besoin de
cette app : ils utilisent le formulaire externe.

## Comment ça s'articule avec le formulaire des employés

```
Employé              Formulaire externe         Excel (OneDrive/SharePoint)         App iOS (vous)
--------              -------------------         ----------------------------         ---------------
Remplit le    ---->   Écrit une ligne      ---->  Nouvelle ligne, colonne      ---->   Onglet "À valider"
formulaire            dans le tableau              Statut vide ("en attente")           liste la ligne
                       Excel                                                            
                                                                                        Vous appuyez sur
                                                                                        Valider ou Refuser
                                                    Colonne Statut mise à jour   <----   
                                                    ("Validée" / "Refusée")
```

L'app ne crée pas elle-même le formulaire ni les colonnes Excel : c'est à
vous (ou votre IT) de créer le formulaire et le tableau une fois (étape 2
ci-dessous). N'importe quel outil peut alimenter le tableau tant qu'il écrit
dans les bonnes colonnes.

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

## 2. Préparer le formulaire et le fichier Excel

### 2.1 Le tableau Excel

1. Créez (ou choisissez) un fichier `.xlsx` sur OneDrive ou dans une
   bibliothèque de documents SharePoint, par exemple :
   `Demandes/DemandesMateriel.xlsx`.
2. Sur la première feuille, créez un **tableau** (onglet *Insertion* >
   *Tableau*) avec au moins ces colonnes (l'ordre n'a pas d'importance, et
   des colonnes supplémentaires — ex : ajoutées automatiquement par
   Microsoft Forms comme "ID" ou "Heure de début" — ne posent aucun problème,
   l'app les ignore) :

   | Demandeur | Email demandeur | Bénéficiaire | Email bénéficiaire | Matériel | Justification | Statut |
   |-----------|------------------|--------------|---------------------|----------|----------------|--------|

   Une colonne **Date** est optionnelle (l'app l'affiche si présente).

   L'app reconnaît chaque colonne par son **intitulé** (insensible à la
   casse et aux accents), avec plusieurs variantes acceptées :
   - Demandeur : `Demandeur`, `Nom du demandeur`
   - Email demandeur : `Email demandeur`, `E-mail demandeur`, `Mail demandeur`, `Email`
   - Bénéficiaire : `Bénéficiaire`, `Nom du bénéficiaire`, `Pour qui`
   - Email bénéficiaire : `Email bénéficiaire`, `E-mail bénéficiaire`, `Mail bénéficiaire`
   - Matériel : `Matériel`, `Type de matériel`, `Équipement`
   - Justification : `Justification`, `Motif`, `Raison`
   - Statut : `Statut`, `Statut de la demande`, `État`
   - Date : `Date`, `Date de la demande`, `Horodateur`, `Heure de début`

   **Important** : la colonne **Statut** doit exister dans le tableau — c'est
   elle que l'app met à jour ("Validée" / "Refusée") lors du traitement d'une
   demande. Une case vide dans cette colonne est traitée comme "en attente".
   Si votre formulaire ne la remplit pas automatiquement, laissez-la vide à
   la création : c'est le comportement attendu.

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

### 2.2 Le formulaire des employés

Créez le formulaire avec l'outil de votre choix (Microsoft Forms est le plus
simple : dans l'onglet *Réponses*, activez *Ouvrir dans Excel* ou branchez un
flux Power Automate pour écrire chaque réponse comme une nouvelle ligne du
tableau créé à l'étape 2.1). Le formulaire doit demander :

- Nom et email du demandeur (la personne qui fait la demande),
- Nom et email du bénéficiaire (la personne pour qui est le matériel),
- Type de matériel (ordinateur portable/fixe, téléphone, clé USB, autre),
- Justification de la demande.

Assurez-vous que chaque réponse crée une ligne dans le **même tableau**
Excel (pas juste dans la feuille en dessous : dans Excel, une nouvelle ligne
ajoutée juste sous un tableau n'en fait automatiquement partie que si
l'option d'extension automatique du tableau est activée — vérifiez-le après
un premier test).

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
   valeurs de l'étape 2.1.
3. **Votre nom** / **Votre email** : utilisés en copie du mail envoyé et comme
   destinataire indiqué pour le retour du document signé.
4. Bouton **Se connecter à Microsoft 365** : une fenêtre de connexion
   Microsoft s'ouvre (Safari intégré). Connectez-vous avec le compte qui a
   accès au fichier Excel.

## 5. Utiliser l'app

1. Onglet **À valider** (écran principal) : liste toutes les lignes du
   tableau Excel dont le statut n'est ni "Validée" ni "Refusée". Tirez vers
   le bas pour rafraîchir après qu'un employé a soumis une nouvelle demande.
2. Touchez une demande pour voir son détail, puis :
   - **Valider la demande** → l'app écrit "Validée" dans Excel, génère le
     PDF, puis ouvre la feuille **Mail** pré-remplie (PDF en pièce jointe,
     adressée au bénéficiaire, avec le demandeur et vous en copie).
     Vérifiez et appuyez sur **Envoyer**.
   - **Refuser la demande** → confirmation, puis l'app écrit "Refusée" dans
     Excel. Aucun mail n'est envoyé.
3. Le bénéficiaire signe le PDF reçu (à la main après impression, ou en
   l'annotant directement dans l'app Mail/Fichiers avec l'outil Marqueur) et
   vous le renvoie par retour de mail.
4. Onglet **Ajouter** : pour saisir vous-même une demande reçue par un autre
   canal (elle est directement enregistrée comme "Validée").
5. Onglet **Historique** : liste toutes les demandes (en attente, validées,
   refusées) avec leur statut, relues directement depuis le tableau Excel.

## Notes techniques

- Aucun backend n'est nécessaire : l'app appelle directement l'API Microsoft
  Graph (`workbook/tables/...`) pour lire et écrire dans le classeur Excel
  tel quel — le fichier reste ouvrable normalement dans Excel/Office en ligne,
  et peut être alimenté par n'importe quel outil externe (formulaire, script,
  saisie manuelle).
- Les colonnes sont identifiées par leur **nom d'en-tête**, pas par position :
  l'app est donc tolérante à l'ordre des colonnes et à des colonnes
  supplémentaires que le formulaire externe pourrait ajouter.
- Mettre à jour le statut d'une ligne renvoie l'intégralité de ses valeurs à
  Microsoft Graph (colonne Statut modifiée, le reste inchangé), afin de ne
  perdre aucune donnée saisie par le formulaire externe.
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
- Pas de suivi de statut "signé/retourné" : le retour du PDF signé se fait
  par mail classique, il n'est pas réimporté automatiquement dans Excel.
  Cela pourrait être ajouté en écoutant les mails entrants (ex: via
  Microsoft Graph `mail` API) ou avec une colonne de statut supplémentaire à
  cocher manuellement.
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
