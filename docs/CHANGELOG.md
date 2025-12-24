# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased] - 2025-12-23

### Added

- lightwalletd gRPC client and minimal proto definitions for transparent address support when the backend is Zebra (no `getaddressdeltas` / `getaddressbalance`).
- Release config/env vars for lightwalletd: `LIGHTWALLETD_ENABLED`, `LIGHTWALLETD_HOSTNAME`, `LIGHTWALLETD_PORT`, `LIGHTWALLETD_TLS`, `LIGHTWALLETD_CACERTFILE`.
- `ZcashExplorer.RPC` helper for JSON-RPC calls that aren't wrapped by `:zcashex` (e.g. `getblockhash` by height).

### Changed

- Transparent address pages now attempt zcashd-style address index RPCs first, then fall back to lightwalletd:
  - balance shown from `GetTaddressBalance`
  - tx list shown from `GetTaddressTransactions` (currently limited; does not compute per-tx deltas/amounts)
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

