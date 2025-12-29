# Building Zcash Explorer

This document covers setting up the Elixir/Erlang development environment and building the project.

## Requirements

- Erlang/OTP 26+
- Elixir 1.16+
- PostgreSQL
- Node.js and npm (for assets)

## Version Management with kerl and kiex

This project uses [kerl](https://github.com/kerl/kerl) for Erlang and [kiex](https://github.com/taylor/kiex) for Elixir version management.

### Installing kerl

```bash
curl -O https://raw.githubusercontent.com/kerl/kerl/master/kerl
chmod +x kerl
mv kerl ~/bin/  # or anywhere in your PATH
```

### Installing kiex

```bash
curl -sSL https://raw.githubusercontent.com/taylor/kiex/master/install | bash -s
```

Add to your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
[[ -s "$HOME/.kiex/scripts/kiex" ]] && source "$HOME/.kiex/scripts/kiex"
```

## Building Erlang with kerl

### Prerequisites (Ubuntu/Debian)

```bash
sudo apt-get install -y build-essential autoconf libncurses5-dev libncurses-dev \
  libssl-dev libwxgtk3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev \
  libssh-dev unixodbc-dev xsltproc fop libxml2-utils
```

### Build and Install Erlang

```bash
# Update available releases
kerl update releases

# List available releases
kerl list releases

# Build Erlang (this takes 15-30 minutes)
kerl build 26.2.5.16 26.2.5

# Install to a directory
kerl install 26.2.5 ~/kerl/26.2.5

# Activate Erlang
source ~/kerl/26.2.5/activate

# Verify
erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell
# Should output: "26"
```

### kerl Commands Reference

| Command | Description |
|---------|-------------|
| `kerl update releases` | Fetch latest available Erlang releases |
| `kerl list releases` | List available releases to build |
| `kerl list builds` | List completed builds |
| `kerl list installations` | List installed Erlang versions |
| `kerl build <release> <name>` | Build a release with a given name |
| `kerl install <name> <path>` | Install a build to a directory |
| `kerl cleanup <name>` | Remove build artifacts |
| `kerl delete build <name>` | Delete a build |
| `kerl delete installation <path>` | Delete an installation |

## Building Elixir with kiex

Elixir must be compiled against the same Erlang version you'll use at runtime.

```bash
# Activate Erlang first
source ~/kerl/26.2.5/activate

# List available Elixir versions
kiex list known

# Install Elixir (compiles from source)
kiex install 1.16.3

# The installed version is tagged with OTP version: 1.16.3-26
kiex list

# Use/activate Elixir
kiex use 1.16.3-26
# Or source directly:
source ~/.kiex/elixirs/elixir-1.16.3-26.env

# Verify
elixir --version
```

### kiex Commands Reference

| Command | Description |
|---------|-------------|
| `kiex list known` | List available Elixir versions |
| `kiex list` | List installed Elixir versions |
| `kiex install <version>` | Install an Elixir version |
| `kiex use <version>` | Activate an Elixir version for current shell |
| `kiex default <version>` | Set default Elixir version |
| `kiex uninstall <version>` | Remove an Elixir version |

## Shell Configuration

Add to `~/.bashrc` or `~/.zshrc` to auto-activate on login:

```bash
# Erlang
source ~/kerl/26.2.5/activate

# Elixir
source ~/.kiex/elixirs/elixir-1.16.3-26.env
```

Or create a project-specific activation script:

```bash
# File: activate.sh (in project root)
#!/bin/bash
source ~/kerl/26.2.5/activate
source ~/.kiex/elixirs/elixir-1.16.3-26.env
echo "Activated Erlang/OTP $(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell) and $(elixir --version | head -2 | tail -1)"
```

## Building the Project

### First-time Setup

```bash
# Activate Erlang and Elixir
source ~/kerl/26.2.5/activate
source ~/.kiex/elixirs/elixir-1.16.3-26.env

# Install Hex and Rebar
mix local.hex --force
mix local.rebar --force

# Get dependencies
mix deps.get

# Install Node.js dependencies for assets
npm install --prefix assets

# Create and migrate database
mix ecto.setup

# Compile
mix compile
```

### Running the Development Server

```bash
mix phx.server
```

Or inside IEx:

```bash
iex -S mix phx.server
```

The server will be available at http://localhost:4000

### Running Tests

```bash
mix test
```

### Building a Release

```bash
# Set environment
export MIX_ENV=prod
export SECRET_KEY_BASE=$(mix phx.gen.secret)

# Get production deps
mix deps.get --only prod

# Compile assets
npm run deploy --prefix assets
mix phx.digest

# Build release
mix release
```

The release will be in `_build/prod/rel/zcash_explorer/`.

## Docker Build

```bash
docker build -t zcash-explorer .
docker run -p 4000:4000 zcash-explorer
```

## Cleaning Build Artifacts

```bash
# Remove compiled output (safe to delete, will be rebuilt)
rm -rf _build

# Remove fetched dependencies (will need mix deps.get again)
rm -rf deps

# Remove both
rm -rf _build deps
```

## Troubleshooting

### Permission Errors on _build or deps

If you get permission errors, it's likely from a previous Docker build running as root:

```bash
rm -rf _build deps
mix deps.get
mix compile
```

### Mix.Config Deprecation Warnings

The config files use the old `Mix.Config` syntax. This is cosmetic and doesn't affect functionality. To fix, replace in config files:

```elixir
# Old (deprecated)
use Mix.Config

# New
import Config
```

### Missing Erlang Build Dependencies

If `kerl build` fails, ensure all build dependencies are installed:

```bash
sudo apt-get install -y build-essential autoconf libncurses5-dev libncurses-dev \
  libssl-dev libwxgtk3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev \
  libssh-dev unixodbc-dev xsltproc fop libxml2-utils
```

### Elixir Compiled Against Wrong OTP Version

If you see OTP version mismatch errors, reinstall Elixir after activating the correct Erlang:

```bash
source ~/kerl/26.2.5/activate
kiex install 1.16.3
```

## Current Versions

| Component | Version |
|-----------|---------|
| Erlang/OTP | 26.2.5 |
| Elixir | 1.16.3 |
| Phoenix | 1.6.x |

## References

- [kerl documentation](https://github.com/kerl/kerl)
- [kiex documentation](https://github.com/taylor/kiex)
- [Elixir installation guide](https://elixir-lang.org/install.html)
- [Phoenix Framework](https://www.phoenixframework.org/)
