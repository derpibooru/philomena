# AGENTS.md

This file provides guidance to coding assistants when working with code in this repository.

## Development Environment

Everything runs inside Docker Compose (services: `app`, `postgres`, `opensearch`, `valkey`, `files` (S3 proxy), `mediaproc`, `web`). The recommended setup is the devcontainer, which attaches to the `app` service. `scripts/philomena.sh` is the dev CLI (add `scripts/path` to PATH to get it as `philomena`):

```bash
philomena up            # build + start the dev stack (add --drop-db to reset databases)
philomena down          # stop the stack
philomena test          # run the full Elixir test/lint suite in the app container
```

The app serves at http://localhost:8080 (login: `admin@example.com` / `philomena123`). Vite dev server runs on port 5173.

Elixir commands (`mix ...`) must run inside the `app` container (or the devcontainer terminal) — config points at compose hostnames like `postgres` and `opensearch`, so they fail on the host.

## Commands

### Elixir (run inside the app container)

- `mix test` — run tests (requires postgres + opensearch up; `mix ecto.create && mix ecto.load` first on a fresh DB)
- `mix test test/philomena/users_test.exs` or `...exs:42` — single file / single test
- `mix format` — format; `mix format --check-formatted` is enforced by CI
- `mix credo` — lint
- `mix sobelow --config` and `mix deps.audit` — security checks (CI runs both)
- `mix dialyzer` — static analysis (CI runs it; slow on first run while PLT builds)
- `philomena test` (from host) replicates the full CI sequence: format check → `mix test` → sobelow → deps.audit → dialyzer. It recompiles everything and runs dialyzer — use it as a final pass, not for iteration; iterate with targeted `mix test` runs instead.

**Running tests from the host:** the `app` container pins `MIX_ENV=dev`, so a plain `docker compose exec app mix test` hits the dev database and fails with a sandbox error. Override the env:

```bash
docker compose exec -T -e MIX_ENV=test app mix test [test/path/to/file_test.exs]
```

(and once on a fresh stack, `mix ecto.create && mix ecto.load` with the same `-e MIX_ENV=test`).

Test conventions — file layout, auth-level setup helpers, fixtures, OpenSearch index handling, external-call stubbing — are documented in `test/CONVENTIONS.md`; read it before writing controller or context tests.

### Context development

Before creating or refactoring a `Philomena` domain context, its schemas, or a
controller-facing context API, read `CONTEXT_STYLE.md`. It defines the expected
code shape, changeset and query boundaries, transaction composition, result
types, and testing style.

### Database

- Schema is managed via SQL structure dump, not migration replay: fresh setup uses `mix ecto.load` (loads `priv/repo/structure.sql`), and the `ecto.migrate`/`ecto.rollback` aliases automatically re-dump the structure file — commit it together with new migrations.
- `mix ecto.setup_dev` — create, load, and seed with development data
- `mix reindex_all` — rebuild all OpenSearch indexes

### Frontend (in `assets/`)

- `npm run test` / `npm run test:watch` — vitest with coverage
- `npm run lint` — oxlint + stylelint
- `npm run build` — typecheck (tsc) + vite build

### Rust (in `native/philomena/`)

- `cargo fmt --check`, `cargo clippy -- -D warnings`, `cargo test` — all enforced by CI

### Repo-wide formatting

- `npm run fmt` (repo root) — prettier over everything non-Elixir; CI checks `npx prettier --check .`, plus `typos` and shellcheck for scripts. A pre-commit hook (`.githooks/pre-commit`) runs prettier.

## Architecture

Phoenix 1.8 server-rendered MVC — **no LiveView**. Views/templates use `phoenix_view` with Slime templates (`lib/philomena_web/templates/**/*.html.slime`); `phoenix_html` is pinned to 3.x for Slime compatibility.

Four Elixir app namespaces under `lib/`:

- **`Philomena`** — domain contexts (images, tags, forums, comments, users, filters, galleries, notifications, ...). Each context is a `<name>.ex` module plus a `<name>/` directory of Ecto schemas and helpers. Background jobs live in `lib/philomena/workers/` and run via Exq (Redis/Valkey-backed); contexts enqueue e.g. `IndexWorker`, `ThumbnailWorker`.
- **`PhilomenaWeb`** — controllers, plugs, views, templates. Routing is aggressively RESTful: instead of custom actions there are many small nested singleton controllers (e.g. `Image.VoteController`, `Topic.SubscriptionController`) with only `create`/`delete`. The public JSON API is `lib/philomena_web/controllers/api/json/` and is documented by `openapi.yaml` at the repo root — keep the two in sync. Authorization uses Canada/Canary (`can?` protocols + plugs).
- **`PhilomenaQuery`** — the search layer. `parse/` is a nimble_parsec-based parser for the user-facing search query language; `search.ex` + `search/` is the OpenSearch client. Each searchable domain implements the `PhilomenaQuery.Search.Index` behaviour (e.g. `Philomena.Images.SearchIndex`) defining the index mapping and document serialization. Data flow: writes go to Postgres, then documents are (re)indexed into OpenSearch via `PhilomenaQuery.Search.reindex`/`IndexWorker`.
- **`PhilomenaMedia`** — media intake pipeline: `analyzers/` (mime/dimension/duration detection), `processors/` (per-format thumbnailing/optimization), intensities for duplicate detection, and `objects.ex` for S3 storage (ex_aws; s3proxy in dev).
- **`PhilomenaProxy`** — outbound HTTP: camo URL signing and `scrapers/` that fetch image metadata from external sites for upload-by-URL.

**Native code:** `native/philomena/` is a Rustler NIF crate (exposed as `Philomena.Native`) handling Markdown rendering via a forked comrak, plus other hot paths. The same Cargo workspace contains `mediaproc`/`mediaproc_client`/`mediaproc_server` — an RPC service (separate `mediaproc` compose container) that performs actual media processing so the BEAM isn't blocked by ffmpeg/imagemagick work.

**Frontend:** TypeScript (no framework) in `assets/js`, built with Vite, tested with vitest; CSS uses PostCSS with mixins/vars.
