# Transmission : dossier de téléchargement

Transmission doit télécharger dans **`/downloads/incoming`**, jamais dans
`/downloads/complete/Films` : c'est le dossier racine de Radarr, et Radarr refuse un client
qui écrit dans sa bibliothèque. `incoming/` et `complete/` sont sur le même montage
(`./medias` → `/downloads`), donc Radarr et Sonarr importent par hardlink : import instantané,
pas de duplication disque, et le torrent continue de seeder.

Ce réglage vit dans `transmission/config/settings.json` : l'image n'expose aucune variable
d'environnement pour lui. Transmission **réécrit ce fichier à l'arrêt** : ne jamais l'éditer
pendant que le service tourne.

## Méthode A (recommandée) : interface web, service en marche

1. `https://transmission.barlito.fr` → Préférences → onglet Torrents.
2. **Download to** : `/downloads/incoming`.
3. Vérifier que **Keep incomplete files in** vaut `/downloads/incomplete`.
4. Enregistrer. Les torrents en cours gardent leur emplacement, seuls les nouveaux vont dans
   `incoming/`.

## Méthode B : à la main, service arrêté

```bash
cd ~/projects/plex

# Créer le dossier avant, sinon Docker le crée en root:root et Transmission (1000:1000) ne peut pas y écrire
mkdir -p medias/incoming && chown 1000:1000 medias/incoming

docker service scale plex_transmission=0

cp transmission/config/settings.json transmission/config/settings.json.bak
sed -i 's#"download-dir": "/downloads/complete/Films"#"download-dir": "/downloads/incoming"#' \
  transmission/config/settings.json
grep -E '"(download-dir|incomplete-dir)"' transmission/config/settings.json
# attendu : "/downloads/incoming" et "/downloads/incomplete"

docker service scale plex_transmission=1
```

## Client de téléchargement dans Radarr et Sonarr

Settings → Download Clients → Transmission : hôte `transmission`, port `9091`, URL base
`/transmission/`, sans SSL. Toujours le nom de service interne : passer par
`https://transmission.barlito.fr` ferait intercepter l'API par Authelia.
