# logiciels

## Suivi de mails & relances (Microsoft 365)

Application web locale (Next.js) qui se connecte à ta boîte Microsoft 365 via
Microsoft Graph pour :

- te montrer tes mails envoyés récemment et te laisser **choisir lesquels
  suivre** (rien n'est suivi automatiquement),
- détecter automatiquement si tu as reçu une réponse dans la même conversation,
  pour chaque mail que tu as choisi de suivre,
- te signaler ceux restés sans réponse après un délai configurable,
- **vérifier ça tout seul à intervalle régulier**, tant que l'application
  tourne (même onglet fermé),
- te permettre de créer en un clic un **brouillon** de relance (jamais d'envoi
  automatique : tu relis et tu envoies toi-même depuis Outlook).

Les données de suivi (quels mails sont suivis, statut, nombre de relances)
sont stockées localement dans un fichier SQLite (`data/tracker.db`), jamais
envoyées ailleurs.

### 1. Inscrire une application dans Microsoft Entra ID (Azure AD)

1. Va sur [Microsoft Entra admin center](https://entra.microsoft.com/) →
   **Identity > Applications > App registrations > New registration**.
2. Nom : `Suivi de mails` (ou ce que tu veux).
3. **Supported account types** : choisis selon ton besoin, en général
   "Accounts in this organizational directory only" pour un compte pro.
4. **Redirect URI** : type `Web`, valeur `http://localhost:3000/api/auth/callback/azure-ad`.
5. Clique **Register**.
6. Note le **Application (client) ID** et le **Directory (tenant) ID** affichés
   sur la page Overview.
7. Va dans **Certificates & secrets > Client secrets > New client secret**,
   crée un secret et copie sa **valeur** immédiatement (elle ne sera plus
   affichée ensuite).
8. Va dans **API permissions > Add a permission > Microsoft Graph >
   Delegated permissions**, et ajoute :
   - `Mail.Read`
   - `Mail.ReadWrite` (nécessaire pour créer les brouillons de relance)
   - `offline_access`
   - `User.Read` (généralement déjà présent par défaut)
   Si ton organisation l'exige, clique **Grant admin consent**.

Aucune permission d'envoi (`Mail.Send`) n'est demandée : l'application ne
peut pas envoyer de mail à ta place, seulement préparer des brouillons.

### 2. Configurer le projet

```bash
cp .env.example .env.local
```

Remplis `.env.local` :

```
AZURE_AD_CLIENT_ID=<Application (client) ID>
AZURE_AD_CLIENT_SECRET=<valeur du secret créé ci-dessus>
AZURE_AD_TENANT_ID=<Directory (tenant) ID>
NEXTAUTH_SECRET=<résultat de: openssl rand -base64 32>
NEXTAUTH_URL=http://localhost:3000
```

### 3. Installer et lancer

```bash
npm install
npm run dev
```

Ouvre [http://localhost:3000](http://localhost:3000), connecte-toi avec ton
compte Microsoft 365, puis clique sur **Choisir des mails à suivre**.

### Comment ça marche

- **Choisir des mails à suivre** liste tes 50 derniers mails envoyés
  (`SentItems`) directement depuis Outlook — rien n'est enregistré tant que
  tu ne cliques pas sur **Suivre** en face d'un mail.
- Pour chaque mail suivi encore "en attente", l'app interroge ton dossier
  `Inbox` filtré sur le même `conversationId` : si un message y est arrivé,
  le mail est marqué **Répondu**.
- Un mail suivi sans réponse après le délai configuré (3 jours par défaut,
  modifiable dans l'interface) passe au statut **À relancer**.
- Le bouton **Relancer** crée un brouillon de réponse (via l'action Graph
  `createReply`) pré-rempli avec un message de relance, et l'ouvre dans
  Outlook Web pour que tu le relises et l'envoies toi-même.
- **Ne plus suivre** retire un mail du suivi (il redevient disponible dans
  la liste des mails envoyés récents si tu veux le re-suivre plus tard).

### Vérification automatique des réponses

Un menu déroulant dans l'interface ("Vérif. automatique") permet de choisir
un intervalle (15 min / 30 min / 1 h / 2 h / 4 h, ou désactivé). Tant que le
serveur Next.js tourne (`npm run dev` ou `npm start`), un job en arrière-plan
vérifie toutes les 5 minutes si l'un des utilisateurs connectés est dû pour
une vérification, et regarde s'il y a des réponses aux mails **déjà
suivis** — il n'ajoute jamais de nouveaux mails au suivi tout seul. La page
se recharge elle-même toutes les 60 secondes pour afficher les résultats.

Pour que ça fonctionne sans être reconnecté en permanence, le token de
rafraîchissement Microsoft (obtenu après ta connexion) est conservé dans la
table `oauth_tokens` de la base SQLite locale (`data/tracker.db`, jamais
commitée — voir `.gitignore`). C'est un compromis assumé pour un outil
**local et mono-utilisateur** : ne partage pas ce fichier et ne déploie pas
cette app telle quelle sur un serveur partagé sans revoir ce point.

### Limites connues

- Seuls les mails ayant des destinataires "À" sont suivis.
- Une réponse déplacée automatiquement hors de la boîte de réception (règle
  Outlook) ne sera pas détectée par la vérification actuelle, qui ne
  regarde que `Inbox`.
- La synchronisation automatique nécessite que le serveur reste lancé ; elle
  s'arrête si tu fermes `npm run dev`.
