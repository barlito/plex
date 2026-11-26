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
| Sonarr | `FR HD-UHD`, `FR Anime` | Mêmes qualités ; `FR Anime` met MULTi et VOSTFR au même score et rejette les releases en VF seule |

Les profils et custom formats créés à la main ne sont jamais supprimés ni modifiés
(`delete_old_custom_formats: false`, seuls les profils nommés ci-dessus sont gérés).

Radarr et Sonarr classent d'abord par qualité, puis par score. Pour que la langue passe avant la
résolution, le 1080p et le 2160p sont dans le même groupe : c'est le score qui décide. Les scores de
langue s'additionnent quand un titre porte plusieurs étiquettes (`VFF.VFQ`, `FRENCH.VFF`...).
MULTi est donc placé au-dessus de la somme de tous les scores VF qui peuvent se cumuler, du plus
grand groupe de release française (1950) et du bonus 4K.

| Élément | `FR HD-UHD` | `FR Anime` |
|---|---|---|
| MULTi | 40000 | 0 (compté dans `VO Audio`) |
| VFF / TRUEFRENCH, VF2, VFI, VFB, VOF | 5000 | 0 |
| `FRENCH` seul (format local `French Audio (generic)`) | 4800 | 0 |
| VFQ, VQ (formats TRaSH) | 2500 | 0 |
| VFQ, VQ ou VFB sans VFF / TRUEFRENCH / VF2 / VFI / VOF (format local `Non-FR dub only (banned)`) | -50000 | non utilisé |
| VOSTFR | 0 | 0 (compté dans `VO Audio`) |
| `VO Audio` : MULTi ou VOSTFR / SUBFRENCH / STFR (format local) | non utilisé | 10000 |
| `VF only` : VF seule, sans MULTi ni sous-titres FR (format local) | non utilisé | -10000 |
| VO seule | 0 | 0 |
| Bonus 2160p (format `2160p Bonus`) | 100 | 0 |
| Groupes de release FR (tiers) | jusqu'à 1950 | non utilisés |
| `LQ`, `FR LQ`, `BR-DISK`, `Upscaled`, DV sans repli HDR10 | -10000 | -10000 |
| Règle de mise à niveau (`until_score`) | 4800 | 10000 |

- La VF suffit : à la recherche, une MULTi passe devant une VF, mais dès qu'un fichier en VF
  (VFF, VF2, TRUEFRENCH, `FRENCH` seul) est récupéré, plus aucun re-téléchargement (ni vers la MULTi,
  ni vers la 4K). Une VOSTFR ou une VO peut encore être remplacée par une VF.
- Animes : la VO est voulue, et MULTi vaut exactement VOSTFR. Un seul format (`VO Audio`) porte les
  10000 points, donc le score ne dépend pas des étiquettes qu'un titre cumule (`MULTi.VFF.VFQ` =
  `MULTi` = `VOSTFR` = `SUBFRENCH` = 10000). Une VF seule (`VFF`, `VFQ`, `TRUEFRENCH`, `FRENCH`...)
  vaut -10000 et est rejetée. Le bonus 4K et les groupes de release ne sont pas notés : à score égal,
  c'est la taille qui départage (voir plus bas). Dès qu'un fichier à 10000 est récupéré, plus de
  re-téléchargement.
- Les doublages québécois (VFQ, VQ) ou belges (VFB) seuls sont bannis dans `FR HD-UHD` (Radarr et Sonarr) : `Non-FR dub only (banned)` vaut -50000, ce qui rend `MULTi.VFQ` et `MULTi.VFB` (40000 + 2500 ou 5000 + groupes) négatifs, donc refusés. Un
  titre qui porte aussi une VF France (VFF, TRUEFRENCH, VF2, VFI, VOF) n'est pas touché : `MULTi.VFF.VFQ`,
  `MULTi.VFI.VFQ`, `MULTi.VFF.VFB` et `TRUEFRENCH.VFQ` restent acceptés, et `VF2` (qui regroupe les deux
  doublages) aussi. `MULTi.FRENCH` seul n'est pas banni (souvent de la VFF en pratique).
- `FRENCH` seul (4800) et VFF (5000) sont quasi équivalents : un groupe de release (jusqu'à 1950)
  peut les inverser. L'écart garanti de plus de 2050 ne vaut qu'entre les paliers MULTi, VF
  et VOSTFR/VO.
- Un titre contenant MULTi n'est jamais compté comme `FRENCH` seul (`MULTi.FRENCH`, `MULTi-FRENCH`,
  `FRENCH.MULTi`, `MULTi_FRENCH`).
- Les tailles minimales sont volontairement basses (15 Mo/min en 2160p, 5 Mo/min en 1080p) : les minimums des guides TRaSH rejetaient les encodes « 4KLight » et « HDLight ».
- Tailles préférées (`preferred`) : dans Radarr, 95 Mo/min en 2160p et 60 Mo/min en 1080p, sous les
  plafonds. Dans Sonarr, elles sont égales aux minimums (15 et 5 Mo/min). Sonarr choisit la release
  la plus proche de `durée × preferred` (`CompareSize` dans `DownloadDecisionComparer.cs`) : avec un
  `preferred` bas, la plus légère gagne. Cette comparaison passe en dernier, après la qualité, le
  score, le protocole, l'indexeur et les pairs, et arrondit à 200 Mo : elle ne départage que les
  releases à égalité sur tout le reste.
- Les formats `2160p Bonus`, `French Audio (generic)`, `Non-FR dub only (banned)`, `VO Audio` et `VF only` sont des formats personnalisés locaux, dans
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
