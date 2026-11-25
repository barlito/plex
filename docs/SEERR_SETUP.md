# Configuration de Seerr (demandes famille)

Seerr est exposé sur `https://demandes.barlito.fr`, sans Authelia : l'authentification se fait
avec les comptes Jellyfin. Tous les réglages ci-dessous se font dans l'interface, une fois
(ils sont stockés dans `./seerr/config`).

Prérequis : DNS `demandes.barlito.fr` en place, stack déployée, Radarr, Sonarr et Jellyfin
joignables sur le réseau `traefik_traefik_proxy`.

> Les profils `FR HD-UHD` et `FR Anime` sont créés par la phase 2 (Recyclarr). Tant qu'ils
> n'existent pas, choisir n'importe quel profil, puis le remplacer plus tard dans
> Paramètres > Radarr / Sonarr.

## 1. Assistant de premier lancement

1. Ouvrir `https://demandes.barlito.fr`.
2. Choisir **Jellyfin** comme serveur média.
3. URL interne : `http://jellyfin:8096`. URL externe : `https://jellyfin.barlito.fr`.
4. Se connecter avec le compte Jellyfin d'Axel (il devient administrateur de Seerr).
5. Synchroniser puis activer les bibliothèques **Films**, **SeriesTV** et **Animes**.

## 2. Radarr

Paramètres > Services > Radarr > Ajouter :

- Serveur par défaut : oui. Serveur 4K : **non** (aucun serveur 4K, donc pas de bouton « Demander en 4K »).
- Nom d'hôte : `radarr`, port `7878`, SSL désactivé, clé API : Radarr > Settings > General.
- Profil de qualité : `FR HD-UHD`.
- Dossier racine : `/downloads/complete/Films`.
- Disponibilité minimale : `Released`. Recherche automatique activée.

## 3. Sonarr

Paramètres > Services > Sonarr > Ajouter :

- Serveur par défaut : oui. Serveur 4K : **non**.
- Nom d'hôte : `sonarr`, port `8989`, SSL désactivé, clé API : Sonarr > Settings > General.
- Profil de qualité : `FR HD-UHD`. Dossier racine : `/downloads/complete/SeriesTV`.
- Profil anime : `FR Anime`. Dossier racine anime : `/downloads/complete/Animes`.
- Dossiers de saisons activés, recherche automatique activée.

## 4. Connexion et permissions

Paramètres > Utilisateurs :

- Connexion : **Jellyfin activée, connexion locale désactivée**.
- Permissions par défaut des nouveaux utilisateurs : **Request** (Films, Séries) uniquement,
  **sans Auto-Approve**. Les parents restent donc en validation manuelle.
- Importer les utilisateurs Jellyfin (parents, frère), puis activer à la main
  **Auto-Approve** (et Auto-Approve Films / Séries) pour Axel et le frère uniquement.

## 5. Sécurité (Seerr est exposé sans Authelia)

Paramètres > Utilisateurs, **une fois les comptes de la famille importés** :

- Désactiver **Enable New Jellyfin Sign-In**. Par défaut, n'importe quel compte Jellyfin peut
  se connecter à Seerr : un compte est créé à la volée avec les permissions par défaut
  (vérifié sur la v3.5). Après désactivation, seuls les comptes importés se connectent.

Paramètres > Général :

- Activer **Enable Proxy Support** : Seerr est derrière Traefik, sans ça il ne voit que l'IP
  du proxy.
- Activer **Enable CSRF Protection** (l'accès se fait toujours en HTTPS).

Brute-force : un échec de connexion renvoie un `401` (vérifié sur la v3.5), donc la prison
fail2ban `traefik-badbots` de traefik-base le compte (20 erreurs 4xx par minute). Jellyfin
verrouille aussi un compte après plusieurs échecs (*Tableau de bord > Utilisateurs > profil >
nombre maximal de tentatives*).

## 6. Langue et région

Paramètres > Général : langue d'affichage **Français**, région de découverte **FR**
(et langue des originaux : toutes).

## 7. Notifications ntfy (demandes en attente)

L'image épinglée contient un agent **ntfy natif** (`lib/notifications/agents/ntfy`), il n'y a
donc pas besoin de l'agent Webhook.

1. Choisir un topic aléatoire non devinable, par exemple : `openssl rand -hex 12` (il sert de
   mot de passe : ne pas le committer ni le partager).
2. Paramètres > Notifications > **Ntfy** : activer l'agent.
3. URL du serveur : `https://ntfy.sh`, topic : `<topic-aléatoire>`.
4. Types de notification : cocher **uniquement** « Request Pending Approval ».
5. Tester avec le bouton « Test », après s'être abonné au topic dans l'application ntfy du téléphone.

## 8. Recette après déploiement

- Connexion d'un compte Jellyfin de test : réussie, sans accès aux réglages.
- Demande depuis un compte « parent » : reste en attente et déclenche une notification ntfy.
- Demande depuis un compte « auto » : approuvée et envoyée à Radarr / Sonarr sans validation.
