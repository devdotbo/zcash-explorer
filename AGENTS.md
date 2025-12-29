# Repository Guidelines

## Project Structure & Module Organization

- `lib/zcash_explorer/`: core explorer logic (blocks, transactions, mempool, nodes, lightwalletd client).
- `lib/zcash_explorer_web/`: Phoenix web layer (controllers, LiveView, templates, plugs).
- `assets/`: frontend pipeline (Webpack + Tailwind/PostCSS); outputs are bundled into `priv/static/`.
- `priv/repo/migrations/`: Ecto migrations; `priv/repo/seeds.exs` for seed data.
- `config/`: environment config; `config/releases.exs` loads production settings from environment variables.

## Build, Test, and Development Commands

- Requirements: Erlang/OTP 26+, Elixir 1.16+, PostgreSQL, Node/npm (see `docs/BUILD.md` for setup details).
- First-time tooling: `mix local.hex --force && mix local.rebar --force`.
- `mix setup`: fetch Elixir deps, set up the database, and install Node deps in `assets/`.
- `mix phx.server`: run the dev server at `http://localhost:4000` (starts JS/CSS watchers).
- `mix test`: prepares the test database (create + migrate) and runs ExUnit.
- `mix format`: auto-format Elixir based on `.formatter.exs`.
- Release build: `npm run deploy --prefix assets && mix phx.digest && MIX_ENV=prod mix release` (expects env vars from `.env.example`).
- Docker helpers: `make docker_build`, `make docker_run`, `make docker_clean`.

## Coding Style & Naming Conventions

- Elixir: 2-space indentation; prefer small, composable functions and clear module boundaries between `zcash_explorer` and `zcash_explorer_web`.
- Formatting: run `mix format` before opening a PR; avoid manual reformatting that fights the formatter.
- Frontend: make source changes in `assets/`; avoid editing generated files under `priv/static/` directly.

## Testing Guidelines

- Framework: ExUnit (with Ecto SQL Sandbox). Tests live under `test/` and should be named `*_test.exs`.
- Use existing helpers in `test/support/` (`DataCase`, `ConnCase`, `ChannelCase`) for consistent setup.

## Commit & Pull Request Guidelines

- Commit messages: follow the repository’s existing style — short, imperative subjects (e.g., “Fix …”, “Add …”, “Bump …”).
- PRs: include a clear description, link relevant issues, add screenshots for UI changes, and call out any DB migrations or config/env var changes.

## Security & Configuration Tips

- Do not commit secrets. Use `.env.example` as the template for required runtime variables (notably `SECRET_KEY_BASE`, `ZCASHD_*`, optional `LIGHTWALLETD_*`).
- For security reports, follow the disclosure policy in `README.md` (private report to maintainers).
