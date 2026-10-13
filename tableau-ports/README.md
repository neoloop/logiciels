# Tableau de ports

🇫🇷 Français · 🇬🇧 [English](README.en.md)

Page HTML unique, **sans dépendance ni serveur**, qui vérifie d'un coup d'œil si vos services web internes répondent : un tableau service / hôte / port / chemin, une pastille **en ligne / hors ligne**, le temps de réponse et un auto-rafraîchissement optionnel.

## Aperçu

Tous les services sont testés à l'ouverture de la page :

![Tableau de ports](docs/screenshots/01-tableau.png)

On peut ajouter un service, modifier hôte, port et chemin directement dans le tableau, et activer le test automatique toutes les 60 secondes :

![Ajout d'un service](docs/screenshots/02-ajout-service.png)

## Fonctionnement

- Le test est fait **par votre navigateur** : il envoie une requête HTTP vers `hôte:port/chemin` et mesure le temps de réponse.
- **En ligne** : le serveur répond (peu importe le contenu, même une erreur 404 ou 500). **Hors ligne** : connexion refusée ou pas de réponse en 4 secondes.
- Le résultat dépend donc de **l'endroit où vous ouvrez la page** : il faut être sur le réseau (ou en VPN) qui voit vos serveurs.
- La liste est enregistrée dans le navigateur (`localStorage`). Rien n'est envoyé ailleurs.

## Installation

Il n'y a rien à installer : tout tient dans `index.html`. Choisir une des méthodes.

### 1. En local (le plus simple)

1. Télécharger [`index.html`](index.html) (bouton « Raw » puis Ctrl+S, ou `git clone` du dépôt).
2. Double-cliquer dessus : la page s'ouvre dans le navigateur.
3. Passer à [la configuration](#configuration).

### 2. Sur un NAS Synology (Web Station)

1. Dans **Package Center**, installer **Web Station** si ce n'est pas déjà fait.
2. Dans **File Station**, créer un dossier `web/tableau-ports` et y déposer `index.html`.
3. Dans **Web Station → Web Service → Créer**, choisir *Service statique* et pointer vers ce dossier.
4. Dans **Web Station → Web Portal → Créer**, choisir ce service, **protocole HTTP**, un port libre (ex. `8200`).
5. Ouvrir `http://IP-DU-NAS:8200/`.

### 3. Avec n'importe quel serveur web

```bash
# Python (test rapide, depuis le dossier tableau-ports)
python3 -m http.server 8200

# nginx : copier index.html dans la racine du site
sudo cp index.html /var/www/html/ports.html
```

### 4. Avec Docker

```bash
docker run -d --name tableau-ports -p 8200:80 \
  -v "$PWD":/usr/share/nginx/html:ro nginx:alpine
```

Puis ouvrir `http://localhost:8200/`.

> ⚠️ **Servir la page en HTTP, pas en HTTPS** (sauf si vos services sont aussi en HTTPS) : un navigateur bloque les requêtes `http://` lancées depuis une page `https://` (contenu mixte), et tous les tests passeraient « hors ligne ».

## Configuration

1. Renseigner l'**hôte par défaut** (IP ou nom de votre serveur) en haut de page.
2. Pour chaque ligne : nom du service, port, et chemin (`/` ou une page précise, ex. `/health`). Laisser « Hôte » vide pour utiliser l'hôte par défaut, ou le remplir pour un autre serveur.
3. **+ Ajouter** pour une nouvelle ligne, **✕** pour la supprimer, **Ouvrir** pour aller sur le service.
4. **Tester tout** relance les tests ; cocher **Auto 60 s** pour un suivi continu.
5. **Réinitialiser** remet la liste d'exemple.

Pour changer la liste proposée par défaut, modifier la constante `DEFAULTS` au début du `<script>` de `index.html`.

## Limites

- Le test vérifie qu'un **port répond**, pas que l'application fonctionne correctement.
- Un service qui n'accepte pas les requêtes depuis votre poste (pare-feu) apparaît « hors ligne » même s'il tourne.
