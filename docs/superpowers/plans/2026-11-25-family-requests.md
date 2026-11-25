# Family Requests (Seerr + FR arr profiles) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the family a Jellyfin-login request page (Seerr) that feeds Radarr/Sonarr, with FR-first release scoring and size caps versioned via Recyclarr.

**Architecture:** Two new Swarm services in the existing `plex` stack (`docker-compose.yml`): `seerr` (public, native auth, behind Traefik) and `recyclarr` (no ingress, daily sync of TRaSH French custom formats/profiles into Radarr and Sonarr). App-level settings that only exist in UIs are documented step by step in French docs.

**Tech Stack:** Docker Swarm, Traefik v3 labels, `seerr/seerr`, `ghcr.io/recyclarr/recyclarr`, Radarr/Sonarr (linuxserver).

**Spec:** `docs/superpowers/specs/2026-11-25-family-requests-design.md`

## Global Constraints

- Labels under `deploy.labels`; router `<svc>-secure`, entrypoint `https`, `tls=true`, certresolver `letsencrypt`, middleware `security-headers@file`. Seerr gets **no** `authelia-auth@file`. Every existing service stays byte-identical.
- Network `traefik_traefik_proxy` (external). `PUID=1000`, `PGID=1000`, `TZ=Europe/Paris` where the image supports them.
- Image tags: pin the **minor** (patch floating) if the registry publishes such a tag, otherwise the exact version; never `latest`, never major only. Seerr ≥ 3.4.0, official `seerr/seerr` image only.
- Seerr host: `demandes.barlito.fr`.
- Media paths: `/downloads/complete/Films`, `/downloads/complete/SeriesTV`, `/downloads/complete/Animes` (`./medias` mounted on `/downloads`).
- Code comments in English, only for non-obvious constraints, none line-by-line in YAML. Docs (except README) in French. README in English.
- Commits: conventional, English, **no `Co-Authored-By` and no "Generated with Claude Code"**. Run `git add` and `git commit` as separate commands, `git commit` first in its command.
- Never commit secrets (API keys, ntfy topic). Never run `make undeploy` / `docker stack rm`. Throwaway test containers are removed at the end of the test.

## Review Focus

1. Fresh `make init` then first start: Seerr must be able to write `./seerr/config` (image user vs bind-mount owner 1000) — smoke test in Task 1 starts it on an empty dir.
2. Recyclarr sync against a prod Radarr/Sonarr that already has hand-made profiles and CFs must not delete them — Task 3 test pre-creates one and asserts it survives.
3. Missing `secrets.yml` must fail loudly, and `secrets.yml` must never be tracked — Task 3 asserts `git check-ignore`.
4. Anime: a VF-only release must be unacceptable in `FR Anime` — Task 3 asserts the VF-only CF scores ≤ -10000 in that profile.
5. No re-download to 4K after a 1080p grab — Task 3 asserts cutoff = 1080p-tier on both `FR HD-UHD` profiles with upgrades allowed only up to it.

---

## Phase 1 — branch `feat/phase-1-seerr` (from `feat/arr-stack-bazarr`), PR base `feat/arr-stack-bazarr`

### Task 1: Seerr service

**Files:**
- Modify: `docker-compose.yml` (add `seerr` after `bazarr`), `Makefile` (`init`: `mkdir -p seerr/config`), `.gitignore` (`seerr/config/*`, `!seerr/config/.gitkeep`), `README.md` (services table row)
- Create: `seerr/config/.gitkeep`

**Interfaces:**
- Produces: service `seerr`, internal URL `http://seerr:5055`, router `seerr-secure`, Traefik service `seerr` port 5055, volume `./seerr/config:/app/config`.

- [ ] **Step 1:** Find the tag: query Docker Hub tags for `seerr/seerr`, pick the newest stable ≥ 3.4.0 respecting the tag constraint. Note the image's runtime user (`docker image inspect ... --format '{{.Config.User}}'`).
- [ ] **Step 2: Smoke test (must fail before the change is meaningful):** in the scratchpad, `mkdir cfg`, `docker run -d --name seerr-smoke -v $PWD/cfg:/app/config -p 15055:5055 seerr/seerr:<tag>`; wait for health; `curl -s localhost:15055/api/v1/status` → JSON with `"version"` ≥ 3.4.0; `ls cfg` shows `db/` and `settings.json` (or equivalent) written. If writing fails with a 1000-owned dir, add `user: "1000:1000"` (or the image's documented env) to the service. `docker rm -f seerr-smoke`.
- [ ] **Step 3:** While the smoke container runs, check whether an ntfy agent exists: `docker exec seerr-smoke grep -rl -i ntfy /app/dist | head`. Record the result for Task 2.
- [ ] **Step 4:** Add the service and the other file changes.
- [ ] **Step 5: Verify:** `docker compose -f docker-compose.yml config -q` exits 0; `docker compose -f docker-compose.yml config | grep -A3 'seerr-secure.middlewares'` shows `security-headers@file` only; `git diff docker-compose.yml` touches no other service.
- [ ] **Step 6: Commit** `feat(seerr): add Seerr request portal for the family`.

### Task 2: Seerr setup doc

**Files:**
- Create: `docs/SEERR_SETUP.md` (French)
- Add to the branch: the spec and this plan.

- [ ] **Step 1:** Write the procedure, from spec decision 1, in order: first-run wizard with Jellyfin (`http://jellyfin:8096`, external `https://jellyfin.barlito.fr`, libraries Films/SeriesTV/Animes), Jellyfin sign-in on and local sign-in off, Radarr (`http://radarr:7878`, default, not 4K, profile `FR HD-UHD`, root `/downloads/complete/Films`), Sonarr (`http://sonarr:8989`, default, not 4K, profile `FR HD-UHD`, anime profile `FR Anime`, roots `/downloads/complete/SeriesTV` and `/downloads/complete/Animes`), default user permissions = Request without Auto-Approve, per-user Auto-Approve for Axel and the brother, locale FR + discover region FR, notifications via ntfy (native agent or Webhook agent → `https://ntfy.sh/<random topic>` depending on Task 1 Step 3), only "request pending approval" events.
- [ ] **Step 2:** Note that profiles `FR HD-UHD` / `FR Anime` come from phase 2 (until then, pick any profile and switch later).
- [ ] **Step 3: Commit** `docs(seerr): document setup, permissions and ntfy notifications` (with spec + plan in a separate `docs: add family requests design and plan` commit).
- [ ] **Step 4:** Push, open PR (English title/body, base `feat/arr-stack-bazarr`), body ends with `## TODO` checkboxes: DNS `demandes.barlito.fr`, deploy, run the setup doc, create the ntfy topic, Jellyfin accounts for each family member.

## Phase 2 — branch `feat/phase-2-recyclarr-fr` (from `feat/phase-1-seerr`), PR base `feat/phase-1-seerr`

### Task 3: Recyclarr with FR profiles and size caps

**Files:**
- Modify: `docker-compose.yml` (add `recyclarr`), `Makefile` (`init`: `mkdir -p recyclarr/config`), `.gitignore` (`recyclarr/config/*`, `!recyclarr/config/recyclarr.yml`, `!recyclarr/config/secrets.yml.example`), `README.md`
- Create: `recyclarr/config/recyclarr.yml`, `recyclarr/config/secrets.yml.example`

**Interfaces:**
- Consumes: `http://radarr:7878`, `http://sonarr:8989` on `traefik_traefik_proxy`.
- Produces: Radarr profile `FR HD-UHD`; Sonarr profiles `FR HD-UHD` and `FR Anime`; secrets keys `radarr_api_key`, `sonarr_api_key` (Recyclarr `!secret`, file `/config/secrets.yml`).

Config decisions (spec decision 2):
- Base on TRaSH French custom formats (check `recyclarr config list templates` / the config-templates repo for the current names). MULTi > VFF/TRUEFRENCH > VFQ > other in `FR HD-UHD`; VOSTFR and VO-only allowed but lowest.
- `FR HD-UHD` qualities: WEB + Bluray 1080p and 2160p, 2160p ranked above 1080p, `upgrade.until_quality` = the 1080p group, no Remux. Penalise DV without HDR10 fallback and LQ releases.
- `FR Anime` (Sonarr): MULTi and VOSTFR accepted, VF-only CFs (VFF, VFQ, VF2, VOF... whatever TRaSH names the French-dub-only ones) scored -10000; same quality/cutoff rules.
- Quality definitions max: 2160p qualities 125 MB/min, 1080p qualities 85 MB/min (Radarr and Sonarr).
- `delete_old_custom_formats: false`; only manage the profiles named above.
- Service: no Traefik labels, no `./medias` mount, volume `./recyclarr/config:/config`, `CRON_SCHEDULE=@daily`, `TZ`.

- [ ] **Step 1: Test harness (scratchpad, not committed):** a script that creates a temp network, starts throwaway `lscr.io/linuxserver/radarr` and `lscr.io/linuxserver/sonarr`, reads their API keys from `config.xml`, creates a hand-made quality profile `Manual Keep` in each, writes a temp `secrets.yml`, runs `recyclarr sync` with the repo's `recyclarr.yml` mounted read-only, then asserts via API:
  - Radarr has `FR HD-UHD`; Sonarr has `FR HD-UHD` and `FR Anime`; `Manual Keep` still exists in both.
  - `FR HD-UHD` cutoff is the 1080p group; 2160p ranks above 1080p; no Remux allowed.
  - In `FR HD-UHD`, score(MULTi CF) > score(VFF CF) > score(VFQ CF) > score(VOSTFR CF).
  - In `FR Anime`, every VF-only CF score ≤ -10000 and MULTi/VOSTFR scores ≥ 0.
  - Quality definitions: 2160p max = 125, 1080p max = 85 (both apps).
  - Without `secrets.yml`, `recyclarr sync` exits non-zero.
  Removes all throwaway containers and the network at the end.
- [ ] **Step 2:** Run it against an empty/placeholder config → FAIL.
- [ ] **Step 3:** Write `recyclarr.yml`, `secrets.yml.example`, compose service and the other file changes.
- [ ] **Step 4:** Run the harness → all assertions PASS. `docker compose -f docker-compose.yml config -q` exits 0. `git check-ignore recyclarr/config/secrets.yml` prints the path.
- [ ] **Step 5: Commit** `feat(recyclarr): sync FR-first profiles and size caps to Radarr and Sonarr`.

### Task 4: arr setup doc

**Files:**
- Create: `docs/ARR_FR_SETUP.md` (French)

- [ ] **Step 1:** Document: creating `recyclarr/config/secrets.yml` from the example with the API keys (Settings → General in each app); Radarr and Sonarr Settings → Indexers → **Multi Languages** = French + Original (TRaSH recommendation, instead of Prowlarr's MULTi rewrite); private tracker in Prowlarr + Apps sync; Sonarr anime series use `FR Anime` + root `Animes`; Bazarr: FR language profile, SRT only, embedded PGS/ASS ignored, conversion to SRT on; how to tweak the caps in `recyclarr.yml`.
- [ ] **Step 2: Commit** `docs(arr): document FR indexer, Bazarr and Recyclarr setup`.
- [ ] **Step 3:** Push, open PR (base `feat/phase-1-seerr`), `## TODO`: secrets.yml on the server, Multi Languages setting, tracker in Prowlarr, Bazarr settings, then switch Seerr default profiles to `FR HD-UHD` / `FR Anime`.
