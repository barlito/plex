# Profils FR, Recyclarr et sous-titres (stack arr)

Ce document décrit les réglages à faire à la main pour que Radarr, Sonarr, Prowlarr et Bazarr
cherchent en priorité des releases françaises. Les profils et les scores sont versionnés dans
`recyclarr/config/recyclarr.yml` et synchronisés chaque jour par le service `recyclarr`.

## 1. Clés API pour Recyclarr

Recyclarr lit les clés dans `recyclarr/config/secrets.yml`, un fichier ignoré par git.

1. Récupérer la clé de chaque application : *Settings → General → API Key* dans Radarr, puis dans Sonarr.
2. Sur le serveur, à la racine du repo :

   ```bash
   cp recyclarr/config/secrets.yml.example recyclarr/config/secrets.yml
   ```

3. Remplacer les deux `CHANGE_ME` par les clés (`radarr_api_key`, `sonarr_api_key`).
4. Redéployer ou attendre la prochaine synchronisation quotidienne. Pour lancer une synchronisation
   tout de suite :

   ```bash
   docker exec $(docker ps -q -f name=plex_recyclarr) recyclarr sync
   ```

Si `secrets.yml` est absent ou incomplet, rien n'est synchronisé et le log du service contient une
ligne `[ERR] Config parsing failed ... not defined in secrets.yml`. Recyclarr 8.x termine quand même
avec le code de sortie 0 dans ce cas : il faut regarder les logs (`docker service logs plex_recyclarr`).

Ce qui est créé :

| Application | Profils | Notes |
|---|---|---|
| Radarr | `FR HD-UHD` | WEB et Bluray, 2160p préféré, cutoff 1080p, pas de remux |
| Sonarr | `FR HD-UHD`, `FR Anime` | Mêmes qualités ; `FR Anime` rejette les releases en VF seule |

Les profils et custom formats créés à la main ne sont jamais supprimés ni modifiés
(`delete_old_custom_formats: false`, seuls les profils nommés ci-dessus sont gérés).

Ordre des scores dans `FR HD-UHD` : MULTi (5000) > VFF/TRUEFRENCH (3000) > VFQ (2000) > VOSTFR et
VO seule (0, acceptées en dernier recours). Les formats `LQ`, `FR LQ`, `BR-DISK`, `Upscaled` et
Dolby Vision sans repli HDR10 valent -10000.

## 2. Radarr et Sonarr : langues des indexeurs

Dans chacune des deux applications : *Settings → Indexers → Multi Languages*, choisir **French** et
**Original**. C'est la recommandation TRaSH : elle remplace la réécriture « MULTi » de Prowlarr, qui
n'est donc pas à activer.

## 3. Tracker privé dans Prowlarr

1. *Indexers → Add Indexer*, choisir le tracker et saisir ses identifiants.
2. *Settings → Apps* : vérifier que Radarr et Sonarr sont déclarés (URL `http://radarr:7878` et
   `http://sonarr:8989`, leurs clés API) avec la synchronisation « Full Sync ».
3. *Settings → Apps → Sync App Indexers* pour pousser l'indexeur.

## 4. Séries et animes dans Sonarr

- Séries : profil `FR HD-UHD`, dossier racine `/downloads/complete/SeriesTV`.
- Animes : profil `FR Anime`, dossier racine `/downloads/complete/Animes`, type de série `Anime`.

## 5. Bazarr : sous-titres français en SRT

Objectif : ne jamais forcer Jellyfin à incruster des sous-titres (donc à transcoder).

1. *Settings → Languages* : ajouter un profil de langues `FR` avec le français uniquement, sans
   « forced » ni « HI », puis le définir comme profil par défaut des séries et des films.
2. *Settings → Subtitles* : ignorer les sous-titres embarqués PGS et ASS (cases « Ignore Embedded PGS
   Subtitles » et « Ignore Embedded ASS Subtitles »), et activer la conversion en SRT. Les
   intitulés exacts peuvent varier selon la version de Bazarr.
3. *Settings → Sonarr* et *Settings → Radarr* : URL `http://sonarr:8989` et `http://radarr:7878`,
   avec les clés API.

## 6. Ajuster les plafonds de taille

Les plafonds sont dans `recyclarr/config/recyclarr.yml`, bloc `quality_definition` de chaque
application (en Mo par minute) :

- qualités 2160p : `max: 125` (environ 15 Go pour 2 h) ;
- qualités 1080p : `max: 85` (environ 10 Go pour 2 h).

Modifier les valeurs, commiter, puis relancer la synchronisation (voir section 1). Le remux n'est
pas autorisé dans les profils, donc ses tailles ne sont pas touchées. Pour changer l'ordre des
langues, éditer les `score` des blocs `custom_formats`.
