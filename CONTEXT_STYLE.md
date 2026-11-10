# Context development style

This is the implementation guide for `Philomena` domain contexts and the
schemas, query modules, controllers, fixtures, and tests that touch their public
boundary. It turns recurring choices into defaults for future work.

Read this together with the testing rules in
[`test/CONVENTIONS.md`](test/CONVENTIONS.md). When older code conflicts with
this guide, do not copy the older pattern into new work. Move the code being
changed toward this style without expanding the patch into unrelated cleanup.

## The governing idea

A public context operation should read as the domain workflow itself and be
usable from more than a Phoenix controller. Keep its authorization, loading,
changeset construction, persistence pipeline, and result translation close
enough to understand in one pass. Extract domain rules and reusable
composition; do not hide a one-off workflow behind layers of functions and
structs that only rename its steps.

| Concern                                                    | Preferred home                                                                                  |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| HTTP parameter-envelope extraction and rendering           | Controller                                                                                      |
| Request orchestration and result contract                  | Public context function                                                                         |
| Safe record loading and parent scoping                     | Small private context loader using `Philomena.Loader`                                           |
| Casting, input validation, and state-transition rules      | Schema changeset                                                                                |
| Non-trivial search input                                   | Embedded `QueryForm`                                                                            |
| Ecto/OpenSearch query construction                         | `QueryBuilder`                                                                                  |
| Multi-step database workflow                               | `Philomena.Multi` pipeline                                                                      |
| Reusable transaction step owned by another context         | A `put_*` function that accepts and returns `Philomena.Multi`                                   |
| Indexing, object storage, jobs, and other post-commit work | `Multi.on_commit/2` callback or an explicit success-path action                                 |
| Independently assembled page data                          | A typed page/index/form struct, but only when the schema or changeset cannot carry it naturally |

## Worse is better: choose the smallest sufficient design

For context code, treat complexity as a cost that must earn its keep. Prefer a
small implementation with explicit assumptions and an obvious failure mode to
general defensive machinery for inputs, states, or scale that the domain does
not admit. This is a maintainability rule, not permission to weaken a caller's
validation, authorization, transaction, or persistence guarantees.

- Once a boundary has established an input or output contract, trust that
  contract in the next layer. Do not re-verify, normalize, or wrap values again
  merely to make a trusted path handle cases that its contract excludes.
- Do not add branches for structurally impossible shapes or states when only
  trusted application code can produce them. Let a function-clause error, a
  changeset error, or a database constraint expose a violated internal
  assumption. Handle the case when an external caller, persisted data, or a
  documented public contract can actually produce it.
- For small, bounded operations, prefer the clearest direct traversal or query
  over indexing, caching, generalized dispatch, or an asymptotically faster
  design. Complexity and optimization should follow a real requirement or
  measured evidence.
- Do not add options, wrappers, fallback paths, protocols, result structs, or
  abstractions for a hypothetical caller or a one-off variation. Extract a
  concept when it is reused, enforces a real invariant, or makes the workflow
  easier to understand.
- Keep failures local and legible. A narrow operation that fails loudly at its
  violated assumption is preferable to a broad recovery path that silently
  changes semantics or obscures the original bug.

When deciding whether to add defensive code, name the concrete requirement it
serves: an untrusted boundary, a persisted-data invariant, a concurrency or
rollback guarantee, a documented caller contract, or a demonstrated scale
problem. If there is no such requirement, leave the simpler design in place and
record a short assumption comment only when the reason would otherwise be easy
to lose.

## Public context boundaries

- Accept `%Philomena.Attribution.Actor{}` first for request-facing operations.
  Follow the exact authorization, loading order, nested-resource scoping, and
  normalized error vocabulary in the all-context plan.
- Pass route locators as separate arguments. Controllers should unwrap form
  envelopes and pass the domain attribute map, for example
  `params["dnp_entry"]`, rather than making a context understand the whole
  controller parameter tree.
- Do not recover a route locator or target identity from `attrs`. Load it from
  its separate argument, then seed the newly built schema with the trusted
  association or foreign key before applying the changeset. The changeset may
  still cast an independently editable reference, but a route-selected parent
  is not caller-editable input.
- Use `attrs` for mutation attributes and `params` for search or pagination
  input. Both are caller inputs, not HTTP-only data structures. Names such as
  `creator`, `recipient`, and `closing_user` are preferable to an ambiguous
  `user` when the role matters.
- Keep presentation switches out of context APIs. Do not add optional preload,
  rendering, or bypass options merely to serve one caller. If any one caller
  requires a specific preload, load it for all callers and add it to the result
  contract.
- User-supplied values are cast and validated. A structurally impossible call
  from trusted application code does not need broad normalization solely to
  avoid a function-clause or `Ecto.Changeset.cast/4` error.
- Return the record that was created, updated, or deleted. Do not return a
  parent record merely because a controller needs it for a redirect; preload or
  attach the parent association to the changed record instead.

Controllers remain thin consumers of this API. They may destructure a
changeset's data and preloaded associations to render or redirect. Handle the
specific result shapes the controller owns, then pass everything else to the
fallback as `error -> error`; avoid catch-all patterns that pretend every error
has already been normalized.

## Context APIs are not web APIs

Controllers are one caller of a context, alongside workers, scheduled tasks,
imports, seeds, tests, and IEx/admin maintenance. A controller's nested,
string-keyed request parameters are therefore an adapter concern, not the
context API's contract.

- Public create/update functions receive the resource's attribute map directly;
  they do not expect `%{"resource" => attrs}` or inspect a controller-specific
  top-level key.
- Let an Ecto changeset cast the attributes. This permits a web caller to pass
  its string-keyed form map and a non-web caller to pass a consistently
  atom-keyed map, without context code branching on `Map.get(attrs, "field")`.
  Do not mix atom and string keys in one map: `Ecto.Changeset.cast/4` requires
  a consistent key type.
- Do not function-match attribute maps on string keys or manually parse their
  fields in the context when a cast, validation, virtual field, or named
  changeset helper can express the same rule. Route locators and deliberately
  raw search syntax remain separate inputs with their own parsers/loaders.
- Return `%Ecto.Changeset{}` for expected invalid attributes whenever it
  contains the data a caller needs: normally `{:error, changeset}` rather than
  a bespoke error tuple. The changeset is equally useful to a controller
  rendering errors and to a non-web caller inspecting `errors`, `changes`, or
  normalized data.
- Keep atom errors for non-validation outcomes such as authorization, a missing
  resource, a ban, or a rate limit. Add a tuple or typed form result only when
  it carries independent data that cannot naturally live in `changeset.data` or
  its associations.
- A trusted non-web workflow may have a narrower, explicitly named service API
  with loaded records or a system principal. Do not make the normal
  controller-facing API less reusable by adding a controller-only bypass.

For example, a controller may call
`DnpEntries.create_dnp_entry(actor, params["dnp_entry"])`, while a worker or
test can call the same function with `%{tag_id: tag.id, reason: "..."}`. Both
calls reach the same changeset and receive the same validation contract.

## Prefer a visible vertical workflow

Inline private helpers that are used once and only wrap a single operation.
Typical candidates for inlining are:

- `insert_*`, `update_*`, and `delete_*` helpers that only build a changeset and
  call `Repo`;
- `change_*` helpers that only call `Schema.changeset(record, %{})`;
- `persist_*` helpers that hide the only transaction pipeline using them;
- `transact_and_log` or callback helpers that obscure the concrete write and
  moderation log;
- page-building helpers used by one public loader; and
- parameter helpers that merely remove a controller's top-level form key.

Give ordinary schema changesets an `attrs \\ %{}` default so new/edit loaders
can call `Schema.changeset(record)` directly.

Extract a helper or module when it names a real concept and at least one of the
following is true:

- it is reused;
- it enforces a non-obvious invariant or state transition;
- it builds a substantial query;
- it composes into transactions owned by multiple contexts;
- it isolates an external side effect; or
- keeping it inline would make the public workflow harder, rather than easier,
  to scan.

Do not measure abstraction quality by line count or brevity. Some duplication
in adjacent public operations is preferable when it keeps each mutation's
authorization, write, audit log, and result contract visible.

Keep transitional conversions and one-off maintenance work out of the active
domain context. Give it a focused, independently invocable module with the
smallest public surface needed, so the normal context remains about current
workflows and the legacy code has a clear later-deletion boundary.

## Let changesets own caller input and state rules

Use changesets as the canonical representation of caller-supplied domain
input, including non-persisted input:

- Add virtual schema fields for form values such as a tag name or a compiled
  search query instead of parsing parallel raw maps in the context.
- Put casts, defaults, inclusion/range checks, transition preconditions, and
  field-specific errors in the schema changeset.
- Resolve database-backed references in the context, then pass the loaded
  record or the permitted IDs into the changeset. Schemas should not query the
  repository.
- For state owned by one participant or role, expose a named changeset such as
  `read_changeset/3`, `hidden_changeset/3`, or `transition_changeset/3` rather
  than building a conditional update map in the context.
- When later transaction steps depend on whether a changeset changed a
  meaningful state, calculate that fact while constructing the changeset and
  expose it as a clearly named virtual field (for example,
  `became_unapproved?`). This lets the committed record drive counters,
  reports, and other coupled work; do not re-infer the transition from a stale
  pre-update record or duplicate its predicate in the context.
- Set schema defaults to the real domain default. If transaction composition
  depends on the proposed value, expose a narrow helper that reads it from the
  changeset with `fetch_field!/2` or `get_assoc/2`.
- Use `Ecto.Changeset.apply_action/2` to validate embedded forms that are not
  persisted.
- A rejected state transition is a validation failure, not a successful no-op.
  Put an error on the relevant field (such as already closed, unclaimed, or
  already approved) and return that changeset.

Return the rejected `%Ecto.Changeset{}` for expected validation failures. Keep
its `data`, associations, and submitted values intact so the controller can
render the form without reconstructing domain state.

## Query forms and builders

Move a non-trivial listing/search filter into a schema-backed query form and a
query builder.

The `QueryForm` should:

- use `embedded_schema`;
- cast the caller-facing fields;
- provide canonical defaults;
- validate enums, ranges, arrays, and query syntax; and
- store expensive compiled values in virtual fields when the builder needs
  them.

The `QueryBuilder` should:

- validate with the `QueryForm` and `apply_action/2`;
- return `{:ok, query, query_form}` (or the equivalent OpenSearch body) on
  success and `{:error, changeset}` on failure;
- apply independent filters together instead of accidentally giving one raw
  parameter clause precedence over another;
- include deterministic tie-breaker sorts; and
- stop before authorization, execution, and pagination, which belong to the
  context.

Invalid search input must remain explicit. Return or render its rejected
changeset and do not silently broaden it into an unfiltered query. Prefer a
`nil` result page when the view supports it; an established empty-page contract
is acceptable when the template genuinely requires a page struct.

When there is an HTTP controller, it--not a plug or the query builder--unwraps
the form namespace. On a valid search, build the render changeset from the
applied query form so it retains normalized values for every caller.

## Transactions and side effects

Use `Philomena.Multi`, not `Ecto.Multi`, for new context workflows. A single
database write with no coupled work may call `Repo` directly. Use a Multi as
soon as the operation includes another database mutation, an audit record,
counter maintenance, report work, a lock, reusable transaction composition, or
a post-commit effect.

The public operation should normally show the pipeline:

```elixir
changeset = Schema.changeset(record, attrs)

Multi.new()
|> Multi.update(:record, changeset)
|> ModerationLogs.put_log(:moderation_log, actor, fn %{record: record} ->
  {type, path, body_for(record)}
end)
|> put_reindex_record(:record)
|> Multi.transact()
|> case do
  {:ok, %{record: record}} -> {:ok, record}
  {:error, :record, changeset, _changes} -> {:error, changeset}
end
```

## Schema-table write ownership

Every insertion, update, or delete that affects a schema module's table must
be visible as a function in the context that exposes that schema. A caller
should be able to inspect that context's public write surface and find every
operation that can create, change, or remove rows from the table; do not hide a
table write in an unrelated aggregate, query helper, worker, or schema
collaborator.

- A context may keep its own one-step persistence inline when the operation is
  already a complete public workflow. The changeset, authorization, locking,
  write, and result contract should remain visible together.
- Cross-context collaboration should normally be a documented `put_*`
  function that accepts and returns `Philomena.Multi`. The owning context
  constructs the query, changeset, or insert rows and adds named steps, locks,
  counters, indexing, and other post-commit work there. The caller composes
  that function instead of constructing an `insert`, `insert_all`,
  `update_all`, or `delete_all` for the other context's schema.
- A submodule collaborator should call a documented function on its owning
  context that performs the complete operation. Do not let a recorder,
  maintenance worker, uploader, or verifier update another context's schema
  directly just because it lives below the same namespace.
- This applies to bulk inserts, updates, and deletes as well as changeset
  writes and row deletes. Reads and query construction may be shared, but
  mutation ownership must remain discoverable at the context boundary.
- A `put_*` function owns the post-commit side effects caused by its write.
  If the write changes a search document, queues indexing, broadcasts an event,
  purges an object, or triggers another external effect, attach that work with
  `Multi.on_commit/2` in the owner function. Callers should not have to
  remember a second indexing or notification step after composing the write.

This rule is intentional: locking requirements, lock order, rollback coupling,
and denormalized-counter maintenance cannot be evaluated reliably while writes
to one table are scattered across otherwise unrelated contexts.

- Put all related PostgreSQL changes in the same pipeline: the primary write,
  counters, reports, statistics, subscriptions, and moderation logs should
  commit or roll back together.
- Lock mutable rows with `Multi.lock_one/3` when a decision, transition, or
  counter depends on their current value.
- Treat locks as a documented protocol, not an incidental query option. Lock
  parents before children, scope every child under its locked parent, and use a
  stable order for multiple peer rows so opposite-direction operations cannot
  deadlock. Read denormalized counters and cached pointers only from rows
  protected by that protocol, and update them in the mutation's same Multi.
- Cross-context transaction helpers take a Multi, add clearly named steps, and
  return the Multi. Prefix them with `put_*` when they add work to the pipeline.
- When a later step conditionally adds database work based on earlier Multi
  changes, use `Multi.merge/2` to compose that work into the same transaction.
  Do not replace it with a second transaction or a success callback that needs
  rollback semantics.
- Do not add a direct-`Repo` convenience write alongside a composable
  transaction helper merely for one trusted caller. The owning workflow should
  compose the `put_*` helper into its existing Multi, preserving rollback and
  post-commit behavior. Reserve separately named trusted service APIs for
  workflows that genuinely cannot compose.
- Use step references rather than passing partly persisted records between
  context helpers.
- Register indexing, object storage, job enqueueing, and similar external work
  with `Multi.on_commit/2` when it belongs to a composable workflow. Never run
  it before the database commit or as an irreversible action inside the
  database transaction.
- Treat separate `on_commit` callbacks as unordered. If side effects depend on
  one another, express that ordering in one callback or one explicit
  success-path action rather than relying on registration order.
- Perform rate-limit recording, firehose broadcasts, and other explicitly
  local success actions only after `Multi.transact/1` succeeds.
- Translate the expected primary changeset failure by its exact step name. Do
  not erase the failing step with a generic
  `{:error, _step, reason, _changes}` branch unless the public contract truly
  treats every transaction failure identically.

## Result types: reuse domain data before adding wrappers

Before defining a `SomethingForm`, `SomethingPage`, or `SomethingCreated`
struct, ask whether the same contract can be represented by:

- the schema record itself;
- `%Ecto.Changeset{data: record}`;
- a preloaded association;
- a virtual/calculated field on the returned record; or
- a small tuple of already meaningful values.

Prefer those existing shapes. For example, a created child can carry its
preloaded parent, and a message can carry a conversation with its calculated
message count. Do not introduce a struct that only renames those two values.

A dedicated result struct is appropriate when it assembles independent data
that does not naturally belong to one schema, such as a paginated page with
interactions, a search form with current-user state, or a form with an
independent collection of selectable records. Keep such structs typed and
specific to one boundary.

## Documentation and naming

- Give every public context function an accurate `@spec` and behavior-focused
  `@doc` with realistic success and important error examples.
- Describe authorization differences, parent scoping, atomicity, error
  precedence, and externally visible side effects only when they are useful to
  a caller. Do not narrate private helper structure or repeat the code.
- Keep moduledocs concise and about domain ownership. Avoid promises that just
  restate the architecture.
- Use `load_*` for request-facing reads, `new_*` for form preparation,
  `create_*`/`update_*`/`delete_*` for writes, and `put_*` for transaction
  composition.
- Use comments for a reason, invariant, or unresolved design decision. Delete
  comments that only label an obvious CRUD call.

## Tests and fixtures

Follow `test/CONVENTIONS.md`, including its separate rules for characterization
work. For implementation and refactor tests:

- Exercise the public context API and assert its exact result shape, persisted
  state, associations needed by callers, and important side effects.
- Test rollback coupling for multi-step writes and prove post-commit work does
  not run on a rejected primary changeset where practical.
- Add an `async: false` concurrency test whenever a workflow maintains a
  counter, cached pointer, uniqueness-dependent choice, or state transition
  that can race. Start competing calls together through the SQL sandbox, then
  assert the persisted invariant from base records rather than merely asserting
  that each call returned an expected tuple. Include opposite-order operations
  when a workflow locks multiple peer rows.
- Pin desired domain behavior with a regression test when correcting an
  accidental or unsafe behavior; do not preserve an accident merely because an
  old test described it.
- Do not add a public production function solely for fixtures. Use the real
  public creation path where the fixture convention calls for it. Where direct
  persistence is an established exception, keep it in the fixture module and
  build it through the schema changeset.
- Assert that validation failures preserve the loaded record and associations
  the controller needs, rather than asserting a custom wrapper exists.
- Update context, controller, and controller/context tests together when a
  result contract changes.

## Review checklist

Before considering a context change complete, check:

- Can each public operation be understood without jumping through one-use CRUD
  or transaction helpers?
- Can a controller and a non-web caller use the same operation with the direct
  attribute map appropriate to their boundary?
- Are route-selected identities passed and loaded separately rather than taken
  from caller attributes?
- Does the changeset own casting, validation, and transition rules?
- Does the controller pass domain attrs rather than its whole parameter tree?
- Are IDs loaded safely and nested children constrained by their parents before
  authorization?
- Are related database changes and audit records in one `Philomena.Multi`?
- When current state, counters, or cache pointers can race, are the required
  rows locked in a stable order and the invariant covered by a concurrency test?
- Are external side effects guaranteed to happen only after commit?
- Does an expected validation failure return the actual changeset without
  losing loaded data?
- Is every new result struct carrying information that a schema, association,
  changeset, calculated field, or tuple cannot carry naturally?
- Does invalid search input remain visible instead of becoming an unfiltered
  query?
- Does each defensive branch, abstraction, and optimization serve a concrete
  trust boundary, invariant, contract, or demonstrated scale requirement?
- Do the specs, docs, controller patterns, and tests match the final result
  contract exactly?

Useful current exemplars include the query form/builder pairs under
`Galleries`, `Users`, `Commissions`, `Conversations`, and `DnpEntries`; the
transaction pipelines in `Comments`; the upload callbacks in `Adverts` and
`Badges`; the association-backed item results in `Commissions`; and the
transactional DNP transition in `DnpEntries`.
