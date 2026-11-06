# Controller Test Conventions

Operational reference for writing the characterization tests.

## Ground rules

- These are characterization tests: assert what the code does **today**, not
  what it should do. Never change `lib/` in the same PR as tests.
- Write the naive assertion first, run it, and pin whatever actually happens.
  Anything surprising gets a `# NOTE:` comment in the test; anything that
  looks like a bug should be written to `KNOWN-ODDITIES.md`.
- Definition of done per controller: every routed action has at least one
  test per auth level that can reach it, plus one failure-path test for each
  write action.

## Files and layout

- Test files mirror `lib/philomena_web/controllers/`:
  `lib/philomena_web/controllers/image/vote_controller.ex` →
  `test/philomena_web/controllers/image/vote_controller_test.exs`.
- Start every file with `use PhilomenaWeb.ConnCase, async: true`. Async is
  safe for Postgres-only actions (the SQL sandbox isolates them); actions
  that hit OpenSearch follow the search rules below instead.
- `ConnCase` gives every test a default system filter row and a `conn` with
  a `_ses` fingerprint cookie already set. Pipe it through
  `without_fingerprint/1` to simulate a first request before the frontend
  sets the cookie.

## Auth levels

One test per auth level that can reach the action:

| Level        | Setup                                                            |
| ------------ | ---------------------------------------------------------------- |
| anonymous    | nothing - use `conn` as provided                                 |
| user         | `setup :register_and_log_in_user`                                |
| moderator    | `setup :register_and_log_in_moderator`                           |
| admin        | `setup :register_and_log_in_admin`                               |
| banned       | `setup :register_and_log_in_banned_user`                         |
| banned admin | `setup :register_and_log_in_banned_admin`                        |
| TOTP-enabled | `setup :register_and_log_in_totp_user` (or `log_in_totp_user/2`) |
| API key      | `setup :create_api_user`, then request with `?key=#{api_key}`    |

- `/api/v1` authenticates **only** via the `key` query parameter; session
  login has no effect there. Pin that once per API controller (a
  session-authenticated request behaves as anonymous).
- Use `confirmed_user_fixture()`-based users for API keys - unconfirmed and
  deactivated users crash mid-pipeline on `/api/v1`.
- A ban does not block reads; it surfaces as `conn.assigns.current_ban`,
  which write actions check.

## Fixtures

- Live in `test/support/fixtures/`, one module per context, small composable
  functions. Go through context `create_*` functions where they exist
  (`Forums.create_forum/1`); images, badges, and system filters are the
  sanctioned exceptions.
- Every core context has a fixture module: users, forums, topics, posts,
  comments, images, tags, filters, galleries, conversations, reports, rules,
  channels, badges. `test/philomena/fixtures_test.exs` smoke-tests them and
  doubles as usage examples.
- Attribution-taking contexts (topics, posts, comments, reports) use
  `Philomena.AttributionFixtures.attribution/1`; pass a user or `nil` for
  anonymous. Attrs for these fixtures are string-keyed, controller-style.
- Context functions that enqueue Exq jobs are safe: test config uses Exq's
  in-memory fake queue, so jobs neither reach Valkey nor OpenSearch.

## Singleton toggle controllers (phase 3)

The nearly identical singleton `create`/`delete` controllers (subscriptions,
notification reads, image vote/fave/hide) share generated tests from
`PhilomenaWeb.SingletonToggleTests` (`test/support/singleton_toggle_tests.ex`):

```elixir
use PhilomenaWeb.ConnCase, async: true
use PhilomenaWeb.SingletonToggleTests

# require_authenticated_user halts before the resource loads, so the ids in
# this path need not exist - the anonymous tests build no fixtures.
defp anonymous_path, do: ~p"/images/1/subscription"

defp subscription_target(user) do  # user is always a real user
  image = image_fixture()

  %{
    path: ~p"/images/#{image}/subscription",
    subscribe!: fn -> {:ok, _} = Images.create_subscription(image, user) end,
    subscribed?: fn -> Repo.exists?(...) end
  }
end

subscription_toggle_tests()
```

`read_singleton_tests()` (requires `anonymous_path/0` and `read_target/1`) and
`image_interaction_guard_tests(verbs)` (requires `interaction_path/1`) work
the same way - see the module doc for the exact contracts. Add
controller-specific behavior (hidden topics, restricted forums, parameter
quirks) as ordinary hand-written tests alongside the generator call.

## External calls

All stubbed in `config/test.exs`; smoke-tested by
`test/philomena/external_call_stubs_test.exs`:

- **Mailer** → `Swoosh.Adapters.Test`: assert with
  `import Swoosh.TestAssertions` + `assert_email_sent/1`.
- **S3/object storage** → every ex_aws request succeeds with an empty 200
  (`Philomena.ExAwsHttpClientStub`); no `files` container needed, nothing
  is written anywhere.
- **Scrapers/camo (`PhilomenaProxy.Http`)** → `Req.Test`: a test that
  triggers outbound HTTP must first
  `Req.Test.stub(PhilomenaProxy.Http, fn conn -> Req.Test.json(conn, %{...}) end)`;
  unstubbed requests raise instead of touching the network.
- **Captcha / pwned-passwords** → disabled by config flags.

## Search (OpenSearch)

Search-backed tests hit the real OpenSearch from the compose stack, on
`test_`-prefixed indexes (`:opensearch_index_prefix`) so they can never
touch dev data. Indexes are versioned physical indexes behind an alias
(`test_images` is an alias for `test_images_v1`), exactly as in production -
see `Philomena.SearchMigrator`. Never create a bare index under an alias
name in a test; it blocks the alias and degrades every later search test.
Tests that create or delete indexes (migrator/write-target tests) must call
`PhilomenaQuery.Search.WriteTargets.refresh/0` afterwards so cached write
targets are deterministic, and restore a normal index in `on_exit` using
HTTP-only helpers (no Repo access - the sandbox connection is gone by then).

Every searchable index is dropped and recreated **once** per `mix test` run -
`test_helper.exs` calls `PhilomenaQuery.SearchHelpers.create_all_indexes!()` -
so each run starts from the current mappings. The SQL sandbox does not roll
indexes back, so:

- Module must be `async: false` and tagged `@moduletag :search`.
- Clear the indexes the action reads in setup:
  `PhilomenaQuery.Search.clear_index!(Image)`. This deletes the
  documents (`_delete_by_query`) and leaves the mapping alone; recreating the
  index per test is a cluster-metadata operation and ~100x slower.
- Index fixtures explicitly after inserting them -
  `SearchHelpers.reindex_all!(Image)` - which forces a `_refresh` so documents
  are immediately searchable. There is no single-record variant: serialization
  walks associations, so records have to be loaded with the schema's
  `indexing_preloads/0`, and going through `reindex_all!/1` is what applies
  them.

See `PhilomenaQuery.SearchHelpers` (`test/support/search_helpers.ex`) and
`test/philomena_query/search_helpers_test.exs` for a worked example.

## Assertion idioms

- JSON missing resource: `assert response(conn, 404) == ""` - empty
  `text/plain`, not JSON.
- HTML not-found **and** unauthorized: 302 to `/` - assert
  `redirected_to(conn)` plus `Phoenix.Flash.get(conn.assigns.flash, :error)`.
- Mid-pipeline crashes: `assert_raise Module, ~r/message/` - always pin the
  message, not just the exception module.
- HTML markers: `response =~ "Page Title - Derpibooru"`, headings, entity
  names. No golden HTML files.
- JSON bodies: assert the full decoded structure; pull unordered association
  lists out and compare them sorted, asserting the rest with `Map.delete/2`.
- Give every by-id endpoint a non-integer-id test. An id that no `integer`
  column could hold is treated as a missing resource: JSON endpoints answer
  404, HTML endpoints redirect to `/` with the not-found flash. Note that a
  well-formed _but unknown_ id is authorized as a `nil` load instead: an actor
  whose grant does not cover `nil` takes the unauthorized path, so the two
  cases can carry different flashes.

## Route coverage checklist

[route_coverage.txt](route_coverage.txt) lists every routed action. When a
controller reaches definition-of-done, flip its lines to `[x]` by hand.
`route_coverage_test.exs` fails whenever the file drifts from the router;
regenerate it (marks are preserved) with:

```bash
docker compose exec -T -e MIX_ENV=test app \
  mix run --no-start -e 'PhilomenaWeb.RouteCoverage.regenerate()'
```

## Running tests

From the host (the `app` container pins `MIX_ENV=dev`, so the override is
required):

```bash
docker compose exec -T -e MIX_ENV=test app mix test test/path/to/file_test.exs
```

On a fresh stack, first run (once):
`docker compose exec -T -e MIX_ENV=test app mix ecto.create && ... mix ecto.load`.

Before pushing: `mix format --check-formatted` (in the container) covers
Elixir; `npx prettier --check .` (repo root) covers Markdown. Reserve
`philomena test` for a final full-CI pass.
