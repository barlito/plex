# Plex Media Stack

Self-hosted media server stack running on Docker Swarm behind Traefik.

## Services

| Service | URL | What it does |
|---------|-----|--------------|
| **Plex** | `<host>:32400` | Media server (direct port, not proxied through Traefik) |
| **Jellyfin** | `jellyfin.barlito.fr` | Open-source media server (family's main server) |
| **Emby** | `emby.barlito.fr` | Media server |
| **Transmission** | `transmission.barlito.fr` | BitTorrent client (behind Authelia) |
| **Radarr** | `radarr.barlito.fr` | Movies automation (behind Authelia) |
| **Sonarr** | `sonarr.barlito.fr` | Series and anime automation (behind Authelia) |
| **Prowlarr** | `prowlarr.barlito.fr` | Indexer manager feeding Radarr/Sonarr (behind Authelia) |
| **Bazarr** | `bazarr.barlito.fr` | Subtitles (behind Authelia) |
| **FileBrowser** | `filebrowser.barlito.fr` | Web file manager over the media library (behind Authelia) |
| **Seerr** | `demandes.barlito.fr` | Request portal for the family (Jellyfin login, not behind Authelia: apply the hardening in [docs/SEERR_SETUP.md](docs/SEERR_SETUP.md)) |
| **Recyclarr** | none | Daily sync of FR-first quality profiles, custom formats and size caps into Radarr/Sonarr (no ingress; needs `recyclarr/config/secrets.yml`, see `docs/ARR_FR_SETUP.md`) |
| **cross-seed** | none | One-shot pass that finds torrents on a private tracker matching the files left in `medias/incoming` and injects them into Transmission (no ingress; needs `cross-seed/config/secrets.env`, see [docs/CROSS_SEED.md](docs/CROSS_SEED.md)) |
| **Ubooquity** | `ubooquity.barlito.fr` | Books & comics server (admin UI on `admin.ubooquity.barlito.fr`) |

All media lives under `./medias`, mounted on `/downloads` in every service so Radarr/Sonarr import downloads as hardlinks. Transmission must download into `/downloads/incoming`: see [docs/TRANSMISSION_SETUP.md](docs/TRANSMISSION_SETUP.md).

The server has no GPU: `/dev/dri` is mounted in Jellyfin/Emby but every transcode runs on the CPU.

## Prerequisites

- Docker with Swarm mode enabled (`docker swarm init`)
- [traefik-base](https://github.com/barlito/traefik-base) stack running with the external `traefik_traefik_proxy` network and Authelia — deploy it **first**

## Setup

```bash
make init        # Create the directory structure (medias/, configs, ...)
make deploy      # docker stack deploy plex
```

## Commands

```bash
make deploy      # Deploy the stack
make undeploy    # Remove the stack
make restart     # Undeploy then deploy
make recyclarr-sync  # Sync FR profiles to Radarr/Sonarr now (on the node running recyclarr)
make cross-seed-search  # Trigger a full cross-seed search now (on the node running cross-seed)
```
