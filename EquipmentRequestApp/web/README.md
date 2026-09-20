# Pages web — Demandes de matériel

Deux pages HTML statiques, sans backend, qui complètent l'app iOS :

- **`nouvelle-demande.html`** : formulaire pour que les employés soumettent
  une demande de matériel (destiné à tout le monde).
- **`valider.html`** : liste des demandes en attente + historique, avec les
  actions **Valider** (génère le PDF et l'envoie par mail via Microsoft
  Graph) et **Refuser** (destiné au valideur, en plus ou à la place de l'app
  iOS).

Les deux lisent/écrivent le **même fichier JSON** sur OneDrive/SharePoint que
l'app iOS (voir `../README.md`, section 2) — aucune base de données ni
serveur applicatif n'est nécessaire : tout se passe directement dans le
navigateur, via Microsoft Graph.

## Pourquoi une connexion Microsoft est nécessaire

Microsoft Graph n'autorise aucune lecture/écriture anonyme sur un fichier
privé. Chaque personne (employé ou valideur) se connecte avec son compte
Microsoft 365 professionnel — celui qu'elle utilise déjà pour ses mails. La
session reste active dans le navigateur (MSAL.js la renouvelle tout seul),
donc pas besoin de se reconnecter à chaque visite sur le même appareil.

## Hébergement visé : NAS Synology, réseau interne uniquement

Ces pages sont prévues pour être hébergées sur un NAS Synology, accessibles
**uniquement depuis le réseau du bureau** — aucun port n'est ouvert vers
l'extérieur. L'app iOS, elle, continue de fonctionner depuis n'importe où
puisqu'elle ne parle qu'à Microsoft Graph (dans le cloud), jamais au NAS.

### Contrainte à connaître : HTTPS obligatoire, même en local

La connexion Microsoft (MSAL.js) exige que la page soit servie en **HTTPS**,
y compris pour un accès purement local — un simple `http://192.168.1.x` ne
fonctionnera pas comme URI de redirection. Sans ouvrir de port vers
l'extérieur, on ne peut pas obtenir automatiquement un certificat public
(Let's Encrypt), donc la solution la plus simple est un **certificat
auto-signé**, à accepter une fois dans le navigateur de chaque poste du
bureau.

## 1. Activer HTTPS sur le NAS avec un certificat auto-signé

1. Dans **DSM** (l'interface web du Synology) → **Panneau de configuration**
   → **Sécurité** → **Certificat** : Synology fournit déjà un certificat
   auto-signé par défaut, utilisable tel quel pour un usage interne.
   Alternative plus propre : créez votre propre certificat auto-signé avec
   un nom (CN/SAN) correspondant à l'adresse que vous utiliserez pour
   accéder au NAS (ex : `nas.local` ou l'IP fixe du NAS).
2. **Panneau de configuration** → **Réseau** → **DSM Desktop** (ou
   **Services réseau**) : notez le port HTTPS utilisé par Web Station
   (souvent 5001 pour DSM lui-même ; un site/virtual host créé pour ces
   pages peut avoir son propre port HTTPS — voir étape 2).
3. Sur chaque ordinateur du bureau qui utilisera ces pages : ouvrez l'URL une
   première fois, le navigateur affichera un avertissement de sécurité
   ("certificat non approuvé"). Ajoutez une exception (Chrome/Edge/Firefox le
   permettent tous via "Avancé" → "Continuer quand même" ou équivalent), ou
   installez le certificat comme approuvé dans le magasin de certificats du
   système pour ne plus voir l'avertissement.

## 2. Installer Web Station et déployer les fichiers

1. Dans le **Centre de paquets** DSM, installez **Web Station** (et, selon la
   version de DSM, le paquet **PHP** n'est pas nécessaire ici : ces pages
   sont 100% statiques HTML/JS).
2. Créez un nouveau site (Web Station → **Service Web** → **Créer**) :
   - Type : **Site statique/HTML**.
   - Activez **HTTPS** pour ce site et sélectionnez le certificat de
     l'étape 1.
   - Notez le **port HTTPS** attribué (ou fixez-en un vous-même).
3. Copiez tout le contenu de ce dossier (`web/`, y compris `assets/`) dans le
   dossier partagé associé à ce site (indiqué lors de sa création, en
   général quelque chose comme `/web/<nom-du-site>`).
4. Vérifiez que vous pouvez ouvrir, depuis un poste du bureau :
   - `https://<adresse-du-nas>:<port>/nouvelle-demande.html`
   - `https://<adresse-du-nas>:<port>/valider.html`

   (à ce stade la page s'affiche mais la connexion Microsoft ne fonctionnera
   pas encore — étapes suivantes).

## 3. Déclarer les deux URLs dans Azure AD

Dans l'inscription Azure AD créée pour l'app iOS (voir `../README.md`,
étape 1) :

1. **Authentification** → **Ajouter une plateforme** → **Application
   monopage (SPA)**.
2. Ajoutez les **deux URLs exactes** notées à l'étape précédente (schéma,
   adresse, port et nom de fichier inclus), par exemple :
   - `https://nas.exemple.local:5001/nouvelle-demande.html`
   - `https://nas.exemple.local:5001/valider.html`
3. Enregistrez. Assurez-vous que l'autorisation Graph `Mail.Send` a bien été
   ajoutée (nécessaire pour `valider.html`, qui envoie le mail directement) —
   voir `../README.md` étape 1.8.

Si vous changez l'adresse ou le port du NAS plus tard, il faudra mettre à
jour ces deux URLs dans Azure AD en conséquence.

## 4. Configurer `assets/config.js`

Éditez `web/assets/config.js` (le même fichier est utilisé par les deux
pages) et renseignez :

```js
window.APP_CONFIG = {
  clientId: "...",       // Application (client) ID — le même que l'app iOS
  tenantId: "...",       // Directory (tenant) ID — le même que l'app iOS
  driveBasePath: "/me/drive",  // ou "/sites/{site-id}/drive"
  jsonFilePath: "Suivi_Demandes_Materiel_SIS2B.json", // même fichier que l'app iOS
  validatorEmail: "vous@exemple.com",
  validatorName: "Votre nom",
};
```

Ce sont exactement les mêmes valeurs que dans les Réglages de l'app iOS (voir
`../README.md`, étape 4) — gardez-les synchronisées.

Redéposez le fichier modifié sur le NAS (remplace celui déjà présent).

## 5. Tester

1. Ouvrez `nouvelle-demande.html` depuis un poste du bureau, connectez-vous,
   soumettez une demande de test.
2. Ouvrez `valider.html` : la demande de test doit apparaître dans **À
   valider**. Ouvrez-la, vérifiez/complétez l'email du bénéficiaire, puis
   **Valider** : un mail doit partir (vérifiez le dossier "Éléments envoyés"
   du compte utilisé) avec le PDF en pièce jointe.
3. Ouvrez l'app iOS : la même demande doit apparaître avec le statut à jour
   dans l'onglet **Historique**.

## Notes et limites

- **Accès réseau** : ces pages ne sont volontairement accessibles que depuis
  le réseau où le NAS est joignable (LAN du bureau, ou VPN si vous en avez
  un) — aucun port n'est ouvert vers l'extérieur. Un employé en télétravail
  ne pourra pas soumettre de demande via la page web tant qu'il n'est pas sur
  ce réseau ; l'app iOS, elle, fonctionne de partout.
- **Certificat auto-signé** : chaque nouvel appareil/navigateur verra
  l'avertissement de sécurité une fois. Ce n'est pas un vrai certificat
  public, donc pas adapté si vous souhaitez un jour ouvrir l'accès à
  l'extérieur (il faudrait alors un certificat Let's Encrypt, ce qui suppose
  d'exposer le NAS via un nom de domaine, avec ou sans port ouvert selon la
  méthode de validation utilisée).
- **`valider.html` envoie le mail immédiatement** (via Graph, dès que vous
  cliquez sur "Valider"), contrairement à l'app iOS qui ouvre une fenêtre
  Mail à relire avant envoi — un navigateur ne peut pas préremplir une
  fenêtre de mail native avec une pièce jointe. Vérifiez donc bien les
  informations avant de cliquer.
- Pas d'installation npm/build : MSAL.js et jsPDF sont chargés directement
  depuis un CDN (`cdn.jsdelivr.net`) au chargement de la page. Si le NAS ou
  le poste utilisateur n'a pas accès à Internet (même en LAN, l'accès à ce
  CDN reste nécessaire), les pages ne fonctionneront pas — seul le fichier
  JSON transite par OneDrive, mais les librairies JS elles-mêmes sont
  chargées depuis le CDN public.
