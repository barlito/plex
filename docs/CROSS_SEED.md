# cross-seed : remettre en seed les anciens fichiers

## Ce que ça fait

123 anciens torrents dont les trackers sont morts ont été retirés de Transmission, mais leurs fichiers d'origine (noms de release d'origine) sont toujours dans `medias/incoming`. [cross-seed](https://www.cross-seed.org) (v6) cherche sur le tracker privé configuré dans Prowlarr des torrents **identiques** à ces fichiers, puis injecte le `.torrent` trouvé dans Transmission : le torrent reprend le seed sans rien retélécharger.

Fonctionnement, tel que configuré dans `cross-seed/config/config.js` :

- les fichiers de `/downloads/incoming` sont analysés (`dataDirs`, profondeur 1), ainsi que les torrents déjà présents dans Transmission (API RPC, `http://transmission:9091/transmission/rpc`) ;
- la recherche passe par Prowlarr (`http://prowlarr:9696/<id>/api`), une requête toutes les 60 s ;
- matching `strict` : mêmes noms de fichiers et mêmes tailles, rien d'approximatif ;
- le torrent est injecté dans Transmission (`action: "inject"`) avec des hardlinks créés dans `/downloads/cross-seed` (même volume `./medias`, donc aucune copie, aucun espace en plus) ;
- `skipRecheck: false` : Transmission vérifie chaque torrent injecté avant de seeder ;
- chaque élément n'est cherché qu'une fois par 30 jours, pas de RSS : c'est une passe unique sur l'existant.

Le service tourne en mode `daemon` sans port publié ni label Traefik : aucune interface web.

## Sécurité

cross-seed **ne fait qu'ajouter** des torrents dans Transmission et créer des hardlinks dans `medias/cross-seed`. Il ne supprime ni ne modifie jamais un fichier de la bibliothèque (`medias/complete`) ni de `medias/incoming`. Supprimer un hardlink ne supprime pas l'original tant qu'un autre lien existe.

Le dossier de liens ne peut pas être dans `incoming` (cross-seed le refuse : un `linkDir` ne peut pas être dans un `dataDir`), il est donc à côté : `medias/cross-seed`.

## Mise en place

1. Le tracker privé doit être ajouté dans Prowlarr (fait par le propriétaire).
2. Créer les dossiers : `make init`.
3. Trouver l'id de l'indexeur dans Prowlarr. Au choix :
   - dans l'UI Prowlarr, Indexers : le bouton de copie du flux Torznab de l'indexeur donne une URL du type `http://prowlarr:9696/3/api?apikey=...` ; l'id est le nombre avant `/api` ;
   - ou en ligne de commande, depuis le serveur :
     ```bash
     curl -s -H "X-Api-Key: <CLE_PROWLARR>" http://localhost:9696/api/v1/indexer | grep -E '"(id|name)"'
     ```
     (à adapter si Prowlarr n'est pas joignable ainsi, par exemple via `docker exec` dans le conteneur Prowlarr).
4. Créer le fichier de secrets :
   ```bash
   cp cross-seed/config/secrets.env.example cross-seed/config/secrets.env
   ```
   puis renseigner `CROSS_SEED_PROWLARR_API_KEY` (Prowlarr, Settings, General, API Key) et `CROSS_SEED_PROWLARR_INDEXER_IDS` (ids séparés par des virgules). `CROSS_SEED_API_KEY` est optionnelle (24 caractères minimum). `secrets.env` est ignoré par git ; sans lui, le déploiement échoue.
5. Déployer : `make deploy`.

Les secrets ne sont jamais dans git : `config.js` les lit via `process.env`, alimenté par `env_file` dans `docker-compose.yml`.

## Suivre la progression

```bash
docker service logs -f plex_cross-seed
```

On y voit la validation de la config, puis les recherches (une toutes les 60 s) et, pour chaque match, une ligne d'injection. Un log plus détaillé est écrit dans `cross-seed/config/logs/verbose.current.log`. Dans Transmission, les torrents injectés ont le label `cross-seed-link` ; ils passent par une vérification puis seedent.

Pour relancer une recherche complète immédiatement (en ignorant l'historique), sur le nœud qui héberge le conteneur :

```bash
make cross-seed-search
```

Si cross-seed répond 409, une recherche est déjà en cours ou trop récente. Ne pas utiliser la commande `cross-seed search` à la main pendant que le daemon tourne.

## Désactiver après la passe

Quand les logs montrent que la recherche est terminée (plus de nouvelles lignes de recherche), arrêter le service sans toucher au compose :

```bash
CROSS_SEED_REPLICAS=0 make deploy
```

Ou, à chaud : `docker service scale plex_cross-seed=0` (le prochain `make deploy` le remet à 1 sauf si la variable est à 0). Les torrents injectés restent dans Transmission et continuent de seeder ; les hardlinks dans `medias/cross-seed` doivent rester en place. Pour réactiver : `make deploy` sans la variable.

## Points d'attention

- Le choix de `skipRecheck: false` privilégie la sécurité : la vérification locale coûte du temps disque, pas de bande passante.
- `includeSingleEpisodes` est désactivé : les épisodes isolés d'un pack saison ne sont pas cherchés.
- Un candidat qui ne correspond pas exactement est simplement ignoré, jamais forcé.
