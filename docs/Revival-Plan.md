# Zcash Explorer Revival Plan

## Current State Summary

This is a Phoenix/Elixir-based Zcash block explorer that has been dormant. It uses:
- **Phoenix 1.6** with **LiveView 0.17** for real-time UI
- **Cachex** in-memory caching (no database required)
- **JSON-RPC** to communicate with zcashd
- **Webpack 4** for frontend assets

---

## Key Questions Answered

### Can it connect to Zebra and lightwalletd?

**Current state:** The explorer connects **only via JSON-RPC to zcashd**. It does NOT use gRPC or lightwalletd.

| Backend | Current Support | Notes |
|---------|-----------------|-------|
| zcashd | Yes (JSON-RPC) | Primary supported backend |
| Zebra | Partial | Zebra has RPC compatibility but may not support all methods |
| lightwalletd | No | Would require new gRPC client implementation |

**RPC methods used:**
- `getblockchaininfo`, `getblock`, `getblockheader`, `getblockhashes`
- `getrawtransaction`, `getrawmempool`, `getmempoolinfo`
- `getpeerinfo`, `getnetworksolps`, `getinfo`
- `getaddressbalance`, `getaddressdeltas` (requires address indexing)
- `z_listunifiedreceivers` (for unified address decoding)

### Does it need its own database?

**No.** The codebase has Ecto/PostgreSQL configuration but it's commented out and unused. All data is:
1. Fetched from zcashd via RPC
2. Cached in-memory using Cachex
3. Refreshed by background "warmer" processes every 3-60 seconds

### Does it have real-time support?

**Yes.** Uses Phoenix LiveView with a polling pattern:
- Cache warmers run in background, fetching from zcashd RPC
- LiveView components poll the cache every 1-15 seconds
- Updates pushed to browser via WebSocket

### gRPC support?

**No.** Currently only JSON-RPC to zcashd. Adding lightwalletd/gRPC would be a significant change.

---

## Zebra Compatibility Assessment

Zebra implements a subset of zcashd RPC methods. Critical methods to verify:

| Method | Used For | Zebra Support |
|--------|----------|---------------|
| `getblockchaininfo` | Chain stats | Yes |
| `getblock` | Block details | Yes |
| `getblockhash` | Block by height | Yes |
| `getrawtransaction` | Transaction details | Yes |
| `getrawmempool` | Mempool list | Yes |
| `getmempoolinfo` | Mempool stats | Verify |
| `getpeerinfo` | Network peers | Verify |
| `getnetworksolps` | Hash rate | Verify |
| `getaddressbalance` | Address balance | Likely No (requires indexer) |
| `getaddressdeltas` | Address history | Likely No (requires indexer) |
| `z_listunifiedreceivers` | UA decoding | Verify |

**Recommendation:** Test against Zebra with address-related features disabled initially.

---

## Revival Plan

### Phase 1: Dependency Updates (Critical)

#### 1.1 Elixir/Phoenix Stack
```
Current -> Target
Elixir ~> 1.7 -> ~> 1.15+
Phoenix ~> 1.6 -> ~> 1.7.x
LiveView ~> 0.17 -> ~> 0.20.x
```

#### 1.2 Security Fixes
- [ ] Move hardcoded secrets from `config/config.exs` to environment variables
- [ ] Add rate limiting (plug_attack or hammer)
- [ ] Add CORS configuration for API endpoints
- [ ] Add Content Security Policy headers
- [ ] Fix input validation in viewing key import (command injection risk)
- [ ] Pin `zcashex` dependency to a specific version/tag

#### 1.3 Frontend Modernization
- [ ] Migrate from Webpack 4 to esbuild (Phoenix 1.7 default)
- [ ] Update AlpineJS 2 to 3
- [ ] Update TailwindCSS and PostCSS tooling
- [ ] Remove deprecated packages (hard-source-webpack-plugin, etc.)

### Phase 2: Zebra Compatibility

#### 2.1 Test Current RPC Compatibility
- [ ] Configure explorer to point at Zebra RPC endpoint
- [ ] Identify which RPC calls fail
- [ ] Create compatibility layer or fallbacks for missing methods

#### 2.2 Address Feature Workaround
The address lookup features (`getaddressbalance`, `getaddressdeltas`) likely won't work with Zebra. Options:
1. **Disable address features** when using Zebra
2. **Integrate lightwalletd** for address queries (Phase 3)
3. **Use a third-party indexer** if available

### Phase 3: lightwalletd Integration (Optional Enhancement)

If full address support is needed without zcashd:

#### 3.1 Add gRPC Client
- [ ] Add `grpc` and `protobuf` Elixir dependencies
- [ ] Generate Elixir code from lightwalletd `.proto` files
- [ ] Create `Lightwalletd` client module

#### 3.2 Hybrid Backend
- [ ] Use Zebra for block/transaction data (RPC)
- [ ] Use lightwalletd for address queries (gRPC)
- [ ] Configuration to select backend per feature

### Phase 4: Deployment

#### 4.1 Docker Configuration
Current Dockerfile works but needs updates:
- [ ] Update base image from `elixir:1.14.4-alpine` to latest
- [ ] Update Alpine version
- [ ] Add health checks

#### 4.2 Environment Variables Required
```bash
# Required
SECRET_KEY_BASE=<generate with mix phx.gen.secret>
ZCASHD_HOSTNAME=<zebra-or-zcashd-host>
ZCASHD_PORT=8232
ZCASHD_USERNAME=<rpc-user>
ZCASHD_PASSWORD=<rpc-pass>
EXPLORER_HOSTNAME=<public-hostname>
ZCASH_NETWORK=mainnet|testnet

# Optional (for viewing key feature)
VK_CPUS=0.3
VK_MEM=1024M
VK_RUNNER_IMAGE=nighthawkapps/vkrunner
```

#### 4.3 Network Switching
Already supported via `ZCASH_NETWORK` env var:
- `mainnet` - Shows "ZEC", links to testnet explorer
- `testnet` - Shows "TAZ", amber testnet badge

---

## Implementation Order

### Minimum Viable Revival
1. Update dependencies (mix.exs, package.json)
2. Fix security issues (secrets, input validation)
3. Test against Zebra RPC
4. Deploy with Docker

### Full Feature Parity
5. Implement lightwalletd gRPC client
6. Add address lookup via lightwalletd
7. Add rate limiting and security hardening

---

## Files to Modify

| File | Changes |
|------|---------|
| `mix.exs` | Update all dependency versions |
| `assets/package.json` | Migrate to esbuild or update webpack |
| `config/config.exs` | Remove hardcoded secrets |
| `config/releases.exs` | Add new env var configs |
| `lib/zcash_explorer_web/controllers/page_controller.ex` | Fix input validation |
| `lib/zcash_explorer_web/router.ex` | Add rate limiting, CORS |
| `Dockerfile` | Update base images |

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Zebra RPC incompatibility | High | Test early, document gaps |
| Dependency update breaks | Medium | Update incrementally, test each |
| LiveView 0.17->0.20 migration | Medium | Follow Phoenix upgrade guides |
| Address features unavailable | Medium | Disable or integrate lightwalletd |

---

## User Requirements (Confirmed)

- **Backend:** Zebra + lightwalletd (hybrid approach)
- **Address Lookup:** Yes, essential - requires lightwalletd gRPC integration
- **Deployment:** Docker

---

## Final Implementation Plan

### Step 1: Dependency Updates

**Files:** `mix.exs`, `assets/package.json`

1.1 Update Elixir dependencies:
```elixir
# mix.exs changes
{:phoenix, "~> 1.7.0"}
{:phoenix_live_view, "~> 0.20.0"}
{:phoenix_live_dashboard, "~> 0.8.0"}
{:phoenix_html, "~> 4.0"}
{:grpc, "~> 0.7"}  # NEW - for lightwalletd
{:protobuf, "~> 0.12"}  # NEW - for gRPC
# Remove: {:poison, ...}
```

1.2 Migrate frontend from Webpack 4 to esbuild:
- Remove `assets/webpack.config.js`
- Add esbuild config per Phoenix 1.7 conventions
- Update `config/dev.exs` watchers

### Step 2: Security Fixes

**Files:** `config/config.exs`, `config/releases.exs`, `lib/zcash_explorer_web/router.ex`

2.1 Remove hardcoded secrets from `config/config.exs`
2.2 Add rate limiting plug to router
2.3 Fix input validation in `page_controller.ex` for viewing key import
2.4 Add CSP headers configuration

### Step 3: lightwalletd gRPC Integration

**New Files:**
- `lib/zcash_explorer/lightwalletd/client.ex`
- `lib/zcash_explorer/lightwalletd/service.pb.ex` (generated)

3.1 Obtain lightwalletd `.proto` files from:
    https://github.com/zcash/lightwalletd/tree/master/walletrpc

3.2 Generate Elixir gRPC stubs:
```bash
protoc --elixir_out=plugins=grpc:./lib walletrpc/*.proto
```

3.3 Create Lightwalletd client module with methods:
- `get_address_balance/1` - Get address balance
- `get_address_txids/1` - Get transaction history for address
- `get_transaction/1` - Get transaction details

3.4 Update `AddressController` to use lightwalletd instead of zcashd RPC

### Step 4: Hybrid Backend Configuration

**Files:** `config/releases.exs`, `lib/zcash_explorer/application.ex`

4.1 Add new environment variables:
```bash
# Zebra RPC (block/tx data)
ZEBRA_RPC_HOSTNAME=<zebra-host>
ZEBRA_RPC_PORT=8232
ZEBRA_RPC_USERNAME=<user>
ZEBRA_RPC_PASSWORD=<pass>

# lightwalletd gRPC (address data)
LIGHTWALLETD_HOSTNAME=<lwd-host>
LIGHTWALLETD_PORT=9067
```

4.2 Start both clients in supervision tree:
- `Zcashex` for Zebra RPC (existing, rename config vars)
- `Lightwalletd.Client` for gRPC (new)

### Step 5: Zebra RPC Compatibility

**Files:** `lib/zcash_explorer/` warmer modules

5.1 Test each RPC method against Zebra
5.2 Add fallbacks or disable features for unsupported methods:
- `getnetworksolps` - may not exist in Zebra
- `getpeerinfo` - verify format compatibility
- `z_listunifiedreceivers` - verify support

5.3 Remove address-related RPC calls from Zcashex usage (now via lightwalletd)

### Step 6: Docker Deployment Update

**Files:** `Dockerfile`, `docker-compose.yml` (new)

6.1 Update Dockerfile:
```dockerfile
FROM elixir:1.16-alpine AS build
# ... update build steps for esbuild
```

6.2 Create docker-compose.yml for full stack:
```yaml
version: '3.8'
services:
  explorer:
    build: .
    environment:
      - ZEBRA_RPC_HOSTNAME=zebra
      - LIGHTWALLETD_HOSTNAME=lightwalletd
    ports:
      - "4000:4000"
    depends_on:
      - zebra
      - lightwalletd

  # Your existing Zebra and lightwalletd can be external
  # or included in compose
```

6.3 Add health check endpoint

### Step 7: Network Support (Mainnet + Testnet)

Already supported via `ZCASH_NETWORK` env var. Ensure:
- Zebra RPC points to correct network
- lightwalletd points to correct network
- Run separate containers for mainnet/testnet

---

## Architecture After Changes

```
+------------------+     +------------------+
|      Zebra       |     |   lightwalletd   |
|   (Full Node)    |     |    (Indexer)     |
+--------+---------+     +--------+---------+
         |                        |
    JSON-RPC                    gRPC
         |                        |
+--------+------------------------+---------+
|                Phoenix App                |
|  +------------+  +------------+           |
|  | Zcashex    |  | LWD Client |           |
|  | (Zebra RPC)|  | (gRPC)     |           |
|  +-----+------+  +-----+------+           |
|        |               |                  |
|        v               v                  |
|  +----------------------------------+     |
|  |           Cachex                 |     |
|  |  (blocks, txs, mempool, addrs)   |     |
|  +----------------------------------+     |
|                    |                      |
|                    v                      |
|  +----------------------------------+     |
|  |        Phoenix LiveView          |     |
|  +----------------------------------+     |
+-------------------------------------------+
                    |
               WebSocket
                    |
                    v
              +----------+
              | Browser  |
              +----------+
```

---

## Estimated Effort by Step

| Step | Scope | Complexity |
|------|-------|------------|
| 1. Dependency Updates | Medium | Medium (Phoenix 1.7 migration) |
| 2. Security Fixes | Small | Low |
| 3. lightwalletd gRPC | Large | High (new subsystem) |
| 4. Hybrid Config | Small | Low |
| 5. Zebra Compatibility | Medium | Medium (testing/debugging) |
| 6. Docker Update | Small | Low |
| 7. Network Support | None | Already done |

---

## Critical Files Summary

| File | Purpose |
|------|---------|
| `mix.exs` | Add gRPC deps, update Phoenix |
| `config/releases.exs` | Add lightwalletd config |
| `lib/zcash_explorer/application.ex` | Start gRPC client |
| `lib/zcash_explorer/lightwalletd/` | New gRPC client (create) |
| `lib/zcash_explorer_web/controllers/address_controller.ex` | Switch to lightwalletd |
| `Dockerfile` | Update base images |
| `docker-compose.yml` | Full stack deployment (create) |
