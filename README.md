# Plex Media Stack

Self-hosted media server stack running on Docker Swarm behind Traefik.

## Services

| Service | URL | What it does |
|---------|-----|--------------|
| **Plex** | `<host>:32400` | Media server (direct port, not proxied through Traefik) |
| **Jellyfin** | `jellyfin.barlito.fr` | Open-source media server (hardware transcoding via `/dev/dri`) |
| **Emby** | `emby.barlito.fr` | Media server (hardware transcoding via `/dev/dri`) |
| **Transmission** | `transmission.barlito.fr` | BitTorrent client (behind Authelia) |
| **FileBrowser** | `filebrowser.barlito.fr` | Web file manager over the media library (behind Authelia) |
| **Ubooquity** | `ubooquity.barlito.fr` | Books & comics server (admin UI on `admin.ubooquity.barlito.fr`) |

All media lives under `./medias` (bind mounts), shared between the download client and the media servers. Radarr / Sonarr / Prowlarr are present but currently commented out in the compose file.

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
```
