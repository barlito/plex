"use strict";
// Config reference: https://www.cross-seed.org/docs/basics/options
// Secrets come from cross-seed/config/secrets.env (gitignored), loaded by
// `env_file` in docker-compose.yml: see secrets.env.example.

const prowlarrKey = process.env.CROSS_SEED_PROWLARR_API_KEY;
const indexerIds = (process.env.CROSS_SEED_PROWLARR_INDEXER_IDS || "")
    .split(",")
    .map((id) => id.trim())
    .filter(Boolean);

if (!prowlarrKey || indexerIds.length === 0) {
    throw new Error(
        "CROSS_SEED_PROWLARR_API_KEY and CROSS_SEED_PROWLARR_INDEXER_IDS must be set in cross-seed/config/secrets.env",
    );
}

module.exports = {
    apiKey: process.env.CROSS_SEED_API_KEY || undefined,

    // The Prowlarr URL needs the indexer id before /api (the bare /api is not Torznab).
    torznab: indexerIds.map(
        (id) => `http://prowlarr:9696/${id}/api?apikey=${prowlarrKey}`,
    ),
    sonarr: [],
    radarr: [],

    // Daemon web server: no port is published, only reachable on the stack network.
    host: "0.0.0.0",
    port: 2468,
    notificationWebhookUrls: [],

    // Transmission has no auth here. Torrents are read through the RPC API.
    torrentClients: ["transmission:http://transmission:9091/transmission/rpc"],
    useClientTorrents: true,
    torrentDir: null,
    outputDir: null,

    // One request every 60 s to respect the tracker.
    delay: 60,

    // Orphaned files left over from the dead torrents. maxDataDepth 1 = direct
    // children of incoming/ (release folders or files).
    dataDirs: ["/downloads/incoming"],
    maxDataDepth: 1,

    // Same /downloads mount as dataDirs (hardlinks), but cross-seed refuses a
    // linkDir inside a dataDir.
    linkDirs: ["/downloads/cross-seed"],
    linkType: "hardlink",
    linkCategory: "cross-seed-link",
    flatLinking: false,
    duplicateCategories: false,

    // Only exact matches (same file names and sizes).
    matchMode: "strict",
    // Let Transmission verify every injected torrent before seeding.
    skipRecheck: false,
    autoResumeMaxDownload: 52428800,
    ignoreNonRelevantFilesToResume: false,
    includeSingleEpisodes: false,
    includeNonVideos: false,
    seasonFromEpisodes: null,
    fuzzySizeThreshold: 0.02,

    // Nothing is searched twice within 30 days. excludeOlder must be 2-5x excludeRecentSearch.
    excludeOlder: "60 days",
    excludeRecentSearch: "30 days",
    searchCadence: "1 day",
    searchLimit: 400,
    // No RSS: only existing data matters.
    rssCadence: null,

    action: "inject",
    snatchTimeout: "30 seconds",
    searchTimeout: "2 minutes",
};
