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
   make recyclarr-sync
   ```

Si `secrets.yml` est absent ou incomplet, rien n'est synchronisé et le log du service contient une
ligne `[ERR] Config parsing failed ... not defined in secrets.yml`. Recyclarr 8.x termine quand même
avec le code de sortie 0 dans ce cas : il faut regarder les logs (`docker service logs plex_recyclarr`).

Ce qui est créé :

| Application | Profils | Notes |
|---|---|---|
| Radarr | `FR HD-UHD` | WEB et Bluray, 1080p et 2160p dans un seul groupe de qualités, pas de remux |
| Sonarr | `FR HD-UHD`, `FR Anime` | Mêmes qualités ; `FR Anime` rejette les releases en VF seule |

Les profils et custom formats créés à la main ne sont jamais supprimés ni modifiés
(`delete_old_custom_formats: false`, seuls les profils nommés ci-dessus sont gérés).

Radarr et Sonarr classent d'abord par qualité, puis par score. Pour que la langue passe avant la
résolution, le 1080p et le 2160p sont dans le même groupe : c'est le score qui décide. Les écarts
entre langues dépassent le score maximal d'un groupe de release française (1950) plus le bonus 4K.

| Élément | `FR HD-UHD` | `FR Anime` |
|---|---|---|
| MULTi | 7500 | 20000 |
| VFF / TRUEFRENCH, VF2, VFI, VFB, VOF | 5000 | -10000 (VOF : 0) |
| `FRENCH` seul (format local `French Audio (generic)`) | 4800 | -10000 |
| VFQ, VQ | 2500 | -10000 |
| VOSTFR | 0 | 500 |
| VO seule | 0 | 0 |
| Bonus 2160p (format `2160p Bonus`) | 100 | 100 |
| Groupes de release FR (tiers) | jusqu'à 1950 | jusqu'à 1650 |
| `LQ`, `FR LQ`, `BR-DISK`, `Upscaled`, DV sans repli HDR10 | -10000 | -10000 |
| Règle de mise à niveau (`until_score`) | 7500 | 20000 |

- Une release MULTi atteint le score de coupure : plus aucun re-téléchargement ensuite, donc pas de
  passage en 4K après un fichier 1080p MULTi. Les mises à niveau VOSTFR, puis VF, puis MULTi restent
  possibles.
- Entre deux releases de même langue, le bonus 4K fait préférer le 2160p.
- Dans `FR Anime`, MULTi vaut 20000 car un titre « MULTi.VFF » porte aussi l'étiquette VFF
  (-10000) : il reste accepté, alors qu'une VF seule est rejetée.
- `MULTi.FRENCH` n'est pas compté comme `FRENCH` seul : il reste une release MULTi.
- Les formats `2160p Bonus` et `French Audio (generic)` sont des formats personnalisés locaux, dans
  `recyclarr/config/custom-formats/` (déclarés dans `recyclarr/config/settings.yml`).

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
