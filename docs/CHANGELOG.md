# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased] - 2025-12-28

### Added

- Zaino gRPC support for full address transaction history (queries from block 1 to latest).
- `GetTaddressTxids` RPC method in proto definitions for Zaino compatibility.
- `GetTaddressTxidsPaginated` RPC support for server-side pagination (20 transactions per page, ~450x faster than full fetch).
- Direct txid computation via double-SHA256 hash (no longer depends on `decoderawtransaction` RPC).
- Docker Compose setup for running mainnet and testnet explorers simultaneously (ports 20000 and 20001).
- Single `.env` file configuration supporting both networks with `MAINNET_*` and `TESTNET_*` prefixed variables.
- Dynamic `check_origin` configuration based on `EXPLORER_HOSTNAME` environment variable.
- Repository guidelines (`AGENTS.md`) for AI-assisted development.
- Local patched `zcashex` dependency (`deps_local/zcashex`) to handle JSON-RPC errors on HTTP 200 responses.
- lightwalletd gRPC client and minimal proto definitions for transparent address support when the backend is Zebra (no `getaddressdeltas` / `getaddressbalance`).
- Release config/env vars for lightwalletd: `LIGHTWALLETD_ENABLED`, `LIGHTWALLETD_HOSTNAME`, `LIGHTWALLETD_PORT`, `LIGHTWALLETD_TLS`, `LIGHTWALLETD_CACERTFILE`.
- `ZcashExplorer.RPC` helper for JSON-RPC calls that aren't wrapped by `:zcashex` (e.g. `getblockhash` by height).

### Changed

- Docker Compose now uses Zaino gRPC ports (8138 mainnet, 8137 testnet) instead of lightwalletd.
- Address page queries full blockchain (block 1 to latest) for complete transaction history.
- Address page now uses server-side pagination with cursor-based navigation (20 txs/page, 0.2s load time).
- Address page shows "Page X of Y" with Previous/Next navigation buttons.
- Transparent address pages now attempt zcashd-style address index RPCs first, then fall back to Zaino:
  - balance shown from `GetTaddressBalance`
  - tx list shown from `GetTaddressTxidsPaginated` (paginated, 20 per page)
- `/blocks` (and cache warmers for recent blocks/txs) no longer depend on the non-standard `getblockhashes` RPC; they use `getblockcount` + `getblockhash` + `getblockheader`/`getblock`.
- Search now supports block height inputs by resolving height → hash before falling back to hash-based search.
- Dependency set updated to support gRPC + align Cowboy versions (`plug_cowboy` bumped, `grpc` and `protobuf` added).
- `.env.example` updated with lightwalletd configuration.

### Removed
- Public transaction broadcasting: removed the `/broadcast` routes and navigation links.
- Stale `PriceLive` route (module was missing).

### Fixed

- `/blocks/<height>` now works by resolving block height to hash before calling `getblock`.
- Removed debug `IO.inspect` usage in request paths and cleaned up minor template/format warnings.
- Dockerfile instruction casing for `COPY rel rel`.
- Handle nil `value` fields in transaction inputs/outputs when using Zebra (which does not populate vin.value like zcashd). Fixes "Internal Server Error" on mainnet block and transaction pages.
- Address page 404 when using Zebra: added fallback to lightwalletd for transaction history when `getaddressdeltas` fails (Zebra supports `getaddressbalance` but not `getaddressdeltas`).

