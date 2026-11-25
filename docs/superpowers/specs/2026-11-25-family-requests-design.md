# Interface de demandes pour la famille (Seerr + stack arr)

Date : 2026-11-25 · Branche de départ : `feat/arr-stack-bazarr`

## Intention

Permettre aux parents et au frère d'Axel de demander un film ou une série depuis une page
simple, en se connectant avec leur compte Jellyfin. Tout le reste (recherche sur le tracker,
téléchargement, import, sous-titres FR) se fait sans eux. Le contenu apparaît ensuite dans
Jellyfin (leur serveur) et dans Plex (celui d'Axel), qui partagent la même bibliothèque.

## Objectifs

- Une URL unique pour la famille, connexion avec le compte Jellyfin existant, sans 2FA.
- Approbation **par utilisateur** : parents en validation manuelle, frère et Axel en automatique.
- Recherche orientée FR : MULTi (VF + VO) > VF seule > le reste.
- Qualité : 1080p, ou 2160p si la release reste sous un plafond de taille.
- Configuration du scoring versionnée dans le repo, pas cliquée à la main.

## Non-objectifs

- Supprimer Plex ou Emby : on ne touche à aucun serveur média.
- Corriger le transcodage parasite de Jellyfin : sujet séparé (voir « Risques »).
- Mettre la famille derrière Authelia (multi-utilisateurs, SMTP, TOTP).
- Instances 4K séparées (`radarr-4k`, `sonarr-4k`), quotas de demandes.
- Portail d'accueil (homepage) : hors périmètre, on donne deux URL.

## Anti-objectifs (échec même si « ça marche »)

- La famille voit Radarr, Sonarr, Transmission, des noms de fichiers ou des choix de qualité.
- Une demande des parents reste en attente sans qu'Axel le sache.
- Les releases récupérées provoquent du transcodage chez eux (DV sans repli, sous-titres ASS/PGS).

## Contraintes (existant)

- Docker Swarm, stack `plex` déployée par `make deploy` depuis `docker-compose.yml` (bind mounts,
  pas de fichier prod séparé dans ce repo). Réseau externe `traefik_traefik_proxy` fourni par
  traefik-base.
- Labels Traefik sous `deploy.labels`, routeur `<svc>-secure`, entrypoint `https`, certresolver
  `letsencrypt`, middleware `security-headers@file` partout ; `authelia-auth@file` seulement pour
  les services sans auth native.
- Authelia : backend fichier, un seul utilisateur, `two_factor` sur `*.barlito.fr`, notifier
  fichier. Il reste réservé à Axel.
- Arborescence partagée : `./medias` est monté sur `/downloads` dans Transmission, Radarr, Sonarr,
  Bazarr, Jellyfin et Emby (hardlinks). Racines : `/downloads/complete/Films`,
  `/downloads/complete/SeriesTV`, `/downloads/complete/Animes`. Téléchargement dans
  `/downloads/incoming`.
- Les clients de la famille lisent la 4K : box FAI Android TV, télé 4K récente, PS5.

## Approches étudiées

| | Approche | Compromis |
|---|---|---|
| **A (retenue)** | Une instance Radarr et une instance Sonarr, un profil 1080p/2160p plafonné, approbation réglée par utilisateur dans Seerr | Le plus simple, aucun service en plus. Pas de validation « au fichier » : le plafond de taille est une limite stricte |
| B | Doublons `radarr-4k` / `sonarr-4k`, bouton « Demander en 4K » séparé dans Seerr en validation manuelle | Modèle natif Seerr, mais 2 services en plus, des racines et bibliothèques séparées, des doublons disque |
| C | B pour les films seulement | Un service en plus. Écarté au profit de la simplicité |

Choix d'Axel : **A**. La validation porte sur la *personne*, pas sur le fichier : Seerr approuve
une demande avant que Radarr ait choisi une release, donc on ne peut pas conditionner
l'approbation à la taille.

## Décisions

### 1. Seerr (outil de demandes)

- Image officielle `seerr/seerr` (fusion d'Overseerr et Jellyseerr, v3 en février 2026). Tag
  épinglé sur une version **≥ 3.4.0** (correctif d'un path traversal sur le proxy d'avatars).
  Ne pas utiliser d'image tierce `seerr:latest`, qui peut encore pointer sur Jellyseerr 2.7.
- Volume `./seerr/config:/app/config`, port interne 5055, réseau `traefik_traefik_proxy`.
- Routeur `seerr-secure` sur **`demandes.barlito.fr`** *(choix de Claude, renommable)*, middleware
  `security-headers@file` **sans** Authelia (auth native via Jellyfin, validé par Axel).
- `make init` crée `seerr/config` ; un `.gitkeep` est versionné comme pour les autres services.
- Réglages (UI, à documenter pas à pas) :
  - Serveur média : Jellyfin, URL interne `http://jellyfin:8096`, URL externe
    `https://jellyfin.barlito.fr`. Bibliothèques Films, SeriesTV, Animes.
  - Connexion : sign-in Jellyfin activé, connexion locale désactivée.
  - Radarr : `http://radarr:7878`, serveur par défaut, **non 4K**, profil « FR HD-UHD »
    (décision 2), racine `/downloads/complete/Films`.
  - Sonarr : `http://sonarr:8989`, serveur par défaut, **non 4K**, profil « FR HD-UHD », racine
    `/downloads/complete/SeriesTV`, racine anime `/downloads/complete/Animes`.
  - Aucun serveur 4K déclaré, donc pas de bouton « Demander en 4K ».
  - Permissions par défaut des nouveaux utilisateurs : « Request » **sans** « Auto-Approve »
    (défaut sûr). Frère et Axel : « Auto-Approve » activé à la main.
  - Langue d'affichage FR, région de découverte FR.
  - Notification des demandes en attente vers Axel : **ntfy** (pas de Discord, choix d'Axel).
    Agent ntfy natif de Seerr s'il est présent dans la version épinglée, sinon agent Webhook
    pointé sur le topic ntfy. Serveur : `ntfy.sh` avec un topic aléatoire non devinable
    *(choix de Claude ; un ntfy auto-hébergé serait un repo à part, hors périmètre)*.
    Alternative sans infra : Web Push natif de Seerr.

### 2. Profils FR et plafond de taille (Recyclarr)

- Nouveau service `recyclarr` (image `ghcr.io/recyclarr/recyclarr`, tag épinglé), sans Traefik,
  sans montage de `./medias`. Synchronisation quotidienne via `CRON_SCHEDULE`.
- Config versionnée `recyclarr/recyclarr.yml`, montée en bind. Clés API Radarr et Sonarr
  injectées par variables d'environnement (`!env_var`), jamais versionnées.
- Base : templates TRaSH Guides **French** (custom formats MULTi VFF/VFQ, VFF, VFQ, VOSTFR, etc.).
  Ordre de score : MULTi > VFF/TRUEFRENCH > VFQ > reste. VOSTFR et VO seule ne sont pris
  qu'en l'absence d'autre release.
- Profil « FR HD-UHD » (Radarr et Sonarr) : qualités WEB et Bluray 1080p et 2160p, **2160p
  préféré** quand elle passe sous le plafond, sinon 1080p.
- Formats pénalisés ou interdits : Dolby Vision sans repli HDR10, remux, releases de mauvaise
  qualité (CF TRaSH « LQ »).
- Plafonds via les *quality definitions* *(valeurs de départ choisies par Claude, à ajuster)* :
  - 2160p : max ≈ 125 Mo/min (≈ 15 Go pour 2 h) ;
  - 1080p : max ≈ 85 Mo/min (≈ 10 Go pour 2 h).
- **Personne ne choisit 1080p ou 4K à la main** : à la première recherche, Radarr/Sonarr prend
  la release la mieux classée disponible (2160p sous plafond > 1080p, puis score FR).
  **Cutoff = 1080p** : une fois un fichier 1080p récupéré, pas de re-téléchargement plus tard
  quand une 4K sort *(choix de Claude : évite la bande passante et le disque gaspillés)*.
- Séries : la décision se fait par épisode ou par pack de saison, donc une saison peut mélanger
  1080p et 2160p. Les packs de saison sont préférés (comportement par défaut de Sonarr).
- Animes (validé par Axel) : profil Sonarr dédié « FR Anime » : **MULTi ou VOSTFR, jamais de
  VF seule** (custom formats VF seule en score éliminatoire).

### 3. Sous-titres (Bazarr)

- Profil de langue FR, format **SRT** uniquement : conversion en SRT activée, embarqués
  PGS/ASS ignorés, pour ne pas forcer l'incrustation (donc le transcodage) côté Jellyfin.

### 4. Indexeur

- Le tracker privé d'Axel est ajouté dans Prowlarr à la main, puis synchronisé vers Radarr et
  Sonarr via Prowlarr → Apps. Action manuelle, sans code.

## Découpage

1. **Phase 1, `feat/phase-1-seerr`** : service Seerr (compose, `make init`, `.gitkeep`, README),
   doc FR `docs/SEERR_SETUP.md` (réglages de la décision 1, permissions par utilisateur,
   notification Discord). Vérif : `docker compose -f docker-compose.yml config` valide, puis
   recette après deploy (connexion d'un compte Jellyfin de test, demande en attente pour un
   compte « parent », demande auto pour un compte « auto »).
2. **Phase 2, `feat/phase-2-recyclarr-fr`** : service Recyclarr, `recyclarr/recyclarr.yml`,
   doc des clés API, réglages Bazarr dans la doc. Vérif : `recyclarr sync --preview` sans
   erreur, puis recherche manuelle d'un film connu dans Radarr (une release MULTi passe
   devant une VOSTFR, une 4K au-dessus du plafond est rejetée).

Les actions manuelles (DNS, clés API dans `.env`, tracker dans Prowlarr, réglage Radarr/Sonarr
« Indexers → Multi Languages », topic ntfy) vont dans la section `## TODO` des PR.

Après les deux phases (validé par Axel) :

3. **Check sécurité de l'exposition de Seerr** : brute-force sur la connexion (fail2ban),
   en-têtes, version, surface de l'API publique.
4. **Investigation du transcodage Jellyfin**.

## Risques et points ouverts

- **PS5** : passe par Plex, sans objet.
- **Transcodage Jellyfin actuel** : à diagnostiquer à part, via la « raison du transcodage » dans
  le tableau de bord Jellyfin pendant une lecture.
- **Exposition de Seerr sans Authelia** : la page de connexion est publique. Le fail2ban HTTP de
  traefik-base lit le log d'accès Traefik ; à vérifier qu'un brute-force sur `/api/v1/auth/jellyfin`
  y est bien couvert.
- Nommage `demandes.barlito.fr` et valeurs de plafond : à ajuster par Axel.

## Laissé à l'implémenteur

- Le tag exact de Seerr et de Recyclarr (dernière version stable au moment de la phase).
- Les UID/GID et les droits du bind mount `seerr/config` selon l'utilisateur de l'image.
- Le nom exact des templates et custom formats TRaSH FR dans la version courante de Recyclarr.
