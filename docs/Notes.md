# Zcash Explorer (Deprecated) — Reusability / Modernization Notes

This document captures a repo-specific assessment of what would be required to make this explorer “reusable again”, focused on deployment, security, and dependency maintenance, and whether it can connect to **Zebra** and/or **lightwalletd**.

## Current State (What This Repo Does)

- Stack: Phoenix/Elixir + LiveView UI.
- “Real-time” UX: websockets + polling (Cachex warmers + LiveView refresh), not event-driven subscriptions.
- Backend integration: `Zcashex` (zcashd-style JSON-RPC client) started by the app.
- Database: Postgres/Ecto is present in deps/config, but the Repo is not started in the supervision tree by default.

### Key Code References

- Zcashex process started: `lib/zcash_explorer/application.ex:20`
- Zcashex config via env vars: `config/releases.exs:12`
- Postgres/Ecto present but Repo commented out: `lib/zcash_explorer/application.ex:11`
- Address explorer relies on address index RPCs: `lib/zcash_explorer_web/controllers/address_controller.ex:28`
- “VK” feature runs Docker: `lib/zcash_explorer_web/controllers/page_controller.ex:98`
- Unauthenticated VK callback endpoint: `lib/zcash_explorer_web/router.ex:55`

## Can It Connect To Zebra + lightwalletd?

### lightwalletd

- Not directly.
- This explorer does not use gRPC anywhere; it calls JSON-RPC methods via `Zcashex`.

### Zebra

It can only work with Zebra **if** Zebra exposes the **same** zcashd-style JSON-RPC surface this explorer expects.

This code relies on non-standard / indexer-style RPC methods such as:

- `getblockhashes` (used for “blocks by date”, “recent blocks”, “recent txs” warmers)
- `getaddressbalance` / `getaddressdeltas` (transparent address pages)

If Zebra does not implement these, major pages will break even if basic RPCs like `getblock` work.

### RPC Methods This Explorer Calls

These are invoked through `Zcashex.*` in the app code:

- `getblock`
- `getblockchaininfo`
- `getblockhashes`
- `getblockheader`
- `getinfo`
- `getmempoolinfo`
- `getnetworksolps`
- `getpeerinfo`
- `getrawmempool`
- `getrawtransaction`
- `sendrawtransaction`
- `validateaddress`
- `z_listunifiedreceivers`
- `z_validateaddress`
- `z_validatepaymentdisclosure`

## Does It Need Its Own Database?

### As-is

- No required DB for explorer functionality today; it primarily caches in memory (Cachex).
- Ecto/Postgres scaffolding exists but is not active by default.

### If you want “Zebra + lightwalletd only” (no zcashd-compatible indexer RPC)

- Yes, you’ll need an explorer indexer + DB (or a shim service) to answer queries like:
  - “address deltas / tx history”
  - “blocks in a time range”
  - “reliable tx lookup/indexing guarantees”

## Real-Time Support / gRPC

- The “real-time” experience is implemented via polling + LiveView updates:
  - warmers run roughly every ~5–60 seconds
  - several LiveViews refresh as fast as ~1 second
- A lightwalletd gRPC client can be used for transparent address queries when zcashd-style address index RPCs are unavailable.

## What’s Required To Make It Reusable Again (Practical Plan)

### 1) Decide Your Backend Contract

Pick one of these approaches first; everything else depends on it:

- **Fastest path:** run a **zcashd-compatible RPC/indexer** for the explorer (supports `getblockhashes`, `getaddressdeltas`, etc.). Keep it private.
- **Zebra-first path:** build a **shim/indexer service + DB** that exposes the RPCs this explorer needs, or refactor the explorer to query your indexer’s API directly.

### 2) Make It Build/Run Cleanly

- Remove stale/unused routes and debug logging from request paths.

### 3) Deployment Baseline

- Run **separate instances** for mainnet and testnet (different `ZCASHD_*` + `ZCASH_NETWORK`).
- Put the app behind a TLS reverse proxy; keep RPC creds/network private (do not expose RPC to the Internet).
- Docker build reproducibility:
  - Current Docker build installs Node deps without copying lockfiles first; this can cause supply-chain drift across builds.

### 4) Security Hardening (Important If Public-Facing)

- Rate-limit expensive endpoints:
  - `/search`
  - `/address/*`
  - `/transactions/*`
- Keep `/broadcast` disabled unless you intentionally want public TX relay.
- VK feature:
  - It runs Docker based on user input (`lib/zcash_explorer_web/controllers/page_controller.ex:98`).
  - Options:
    - Disable it entirely, or
    - Move it into a separate, locked-down service, and
    - Authenticate/authorize the callback endpoint (`/api/vk/:hostname`).

### 5) Dependency Modernization + Maintenance

- Upgrade Phoenix/LiveView:
  - Several LiveViews use legacy `~L` rendering; modern LiveView typically uses `~H`/HEEx patterns.
- Update the Node toolchain:
  - Webpack 4 + `--openssl-legacy-provider` is a maintenance and security smell.
- Decide what to do with `:zcashex` (git-pinned dependency):
  - Fork/vendor it if you need Zebra compatibility or long-term maintenance.
- Expand CI beyond Semgrep:
  - format + compile checks
  - basic smoke tests
  - dependency audits
  - container scanning
  - automated dependency PRs (e.g., Dependabot/Renovate)

## Environment Variables (As Used In Releases)

From `config/releases.exs` and `.env.example`, the explorer expects:

- `SECRET_KEY_BASE`
- `EXPLORER_HOSTNAME`
- `EXPLORER_SCHEME` (optional fallback defaults exist)
- `EXPLORER_PORT` (optional fallback defaults exist)
- `PORT` (HTTP listen port; optional fallback defaults exist)
- `ZCASH_NETWORK`
- `ZCASHD_HOSTNAME`
- `ZCASHD_PORT`
- `ZCASHD_USERNAME`
- `ZCASHD_PASSWORD`
- `LIGHTWALLETD_ENABLED` (optional; defaults to enabled)
- `LIGHTWALLETD_HOSTNAME` (required if enabled)
- `LIGHTWALLETD_PORT` (required if enabled)
- `LIGHTWALLETD_TLS` (optional; default false)
- `LIGHTWALLETD_CACERTFILE` (optional; if TLS enabled)
- `VK_CPUS`
- `VK_MEM`
- `VK_RUNNER_IMAGE`
