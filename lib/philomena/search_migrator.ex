defmodule Philomena.SearchMigrator do
  @moduledoc """
  Applies search index mapping changes declared by `PhilomenaQuery.Search.Index`
  modules to the live cluster.

  ## Scheme

  Physical indices are versioned (`images_v2`) and addressed through an alias
  carrying the plain index name (`images`). Each index module declares its
  mapping version with `version/0`; the live version is recorded in the
  index's `mappings._meta.version`. Running `migrate_all/1` (in production via
  `Philomena.Release.migrate_search/0`) compares the two per index and:

  - creates missing indices outright;
  - applies purely additive mapping changes in place with `PUT _mapping`;
  - rebuilds anything else into a new physical index: the new index is created
    unaliased, every node dual-writes incremental document updates to both
    copies (see `PhilomenaQuery.Search.WriteTargets`), documents are bulk
    reindexed from the database into the new index, and the alias is swapped
    atomically before the old index is deleted. Reads are served by the old
    index throughout, so a rebuild has no read downtime;
  - recreates a bare concrete index occupying the alias name (the
    pre-migration legacy state, or an index auto-created by a write to a
    missing alias) destructively: deleted, then built fresh. Search over that
    index is degraded until its reindex completes.

  ## Accepted race

  A document deleted between its bulk batch being read from the database and
  the batch landing in the new index can be resurrected there: the
  dual-written delete lands first and the bulk re-adds the stale copy. The
  window is a single batch, and the same class of race exists in the
  destructive reindex this system replaces. A subsequent update or delete of
  the record self-heals it.
  """

  alias Philomena.SearchIndexer
  alias Philomena.SearchPolicy
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.Search.Api
  alias PhilomenaQuery.Search.MappingDiff
  alias PhilomenaQuery.Search.WriteTargets

  require Logger

  @stale_migration_hours 12

  @type action ::
          :create
          | {:attach_orphan, String.t()}
          | :recreate
          | :rebuild
          | :update_mapping
          | :noop
          | {:warn, String.t()}

  @doc """
  Migrate every searchable schema, sequentially. See `migrate_schema/2`.
  """
  @spec migrate_all(Keyword.t()) :: :ok
  def migrate_all(opts \\ []) do
    Enum.each(SearchIndexer.schemas(), &migrate_schema(&1, opts))
  end

  @doc """
  Idempotently bring the schema's search index to the version declared by its
  index module. Safe to re-run after a crashed or interrupted migration.

  ## Options

  - `force:` - take over an in-progress migration, deleting a fresh migration
    target index left by another run.
  - `maintenance:`, `max_concurrency:` - forwarded to
    `Philomena.SearchIndexer.reindex_schema/2`.
  - `settle_ms:` - override the `:search_migration_settle_ms` dual-write
    settle time.
  - `version:`, `mapping:` - override the index module's declarations (used
    by tests to simulate version bumps).
  """
  @spec migrate_schema(module(), Keyword.t()) :: :ok
  def migrate_schema(schema, opts \\ []) do
    index = SearchPolicy.index_for(schema)
    version = Keyword.get(opts, :version, index.version())
    mapping = Keyword.get(opts, :mapping, index.mapping())
    state = Search.live_state(schema)
    action = plan_action(state, version, mapping)

    Logger.info("Search migration for #{state.alias}: #{inspect(action)}")

    execute(action, schema, state, version, mapping, opts)
  end

  @doc """
  Report the migration state of every searchable schema: live and desired
  versions, the action a migration run would take, and any orphan indices.
  """
  @spec status() :: [map()]
  def status do
    Enum.map(SearchIndexer.schemas(), fn schema ->
      index = SearchPolicy.index_for(schema)
      state = Search.live_state(schema)

      %{
        schema: schema,
        alias: state.alias,
        live_physical: state.live_physical,
        live_version: state.live_version,
        desired_version: index.version(),
        action: plan_action(state, index.version(), index.mapping()),
        orphans: state.orphans
      }
    end)
  end

  @doc """
  Decide, purely from a `PhilomenaQuery.Search.live_state/1` result and the
  desired version and mapping, what `migrate_schema/2` should do. Exposed for
  testing.
  """
  @spec plan_action(map(), pos_integer(), map()) :: action()
  def plan_action(state, desired_version, desired_mapping)

  def plan_action(%{status: :missing} = state, desired_version, _desired_mapping) do
    target = "#{state.alias}_v#{desired_version}"

    if target in state.orphans do
      # Only reachable through manual intervention: the desired index exists
      # complete but nothing holds the alias.
      {:attach_orphan, target}
    else
      :create
    end
  end

  def plan_action(%{status: :legacy}, _desired_version, _desired_mapping), do: :recreate

  def plan_action(%{status: :aliased} = state, desired_version, desired_mapping) do
    live = %{mapping: state.live_mapping, settings: state.live_settings}

    cond do
      is_nil(state.live_version) ->
        :rebuild

      state.live_version == desired_version ->
        case MappingDiff.classify(live, desired_mapping) do
          :equal -> :noop
          _ -> {:warn, "mapping changed without a version bump; bump version/0 to apply it"}
        end

      state.live_version > desired_version ->
        {:warn,
         "live version #{state.live_version} is newer than the code's " <>
           "#{desired_version}; not rolling back"}

      MappingDiff.classify(live, desired_mapping) == :rebuild ->
        :rebuild

      true ->
        :update_mapping
    end
  end

  defp execute(:noop, _schema, state, _version, _mapping, opts) do
    delete_orphans(state, opts)
  end

  defp execute({:warn, message}, _schema, state, _version, _mapping, _opts) do
    Logger.warning("#{state.alias}: #{message}")

    :ok
  end

  defp execute(:create, schema, _state, version, mapping, opts) do
    :ok = Search.create_index!(schema, version: version, mapping: mapping)
    WriteTargets.refresh()

    SearchIndexer.reindex_schema(schema, reindex_opts(opts))
  end

  defp execute({:attach_orphan, target}, schema, state, _version, _mapping, opts) do
    {:ok, %{status: 200}} =
      Api.update_aliases(opensearch_url(), %{
        actions: [%{add: %{index: target, alias: state.alias}}]
      })

    WriteTargets.refresh()

    # The orphan's contents are of unknown freshness; run a full catch-up.
    SearchIndexer.reindex_schema(schema, reindex_opts(opts))
  end

  defp execute(:recreate, schema, state, version, mapping, opts) do
    Logger.warning(
      "#{state.alias}: destructively recreating bare index; " <>
        "search is degraded until the reindex completes"
    )

    :ok = Search.delete_index!(schema)
    execute(:create, schema, state, version, mapping, opts)
  end

  defp execute(:update_mapping, schema, state, version, mapping, opts) do
    :ok = Search.update_mapping!(schema, version: version, mapping: mapping)

    delete_orphans(state, opts)
  end

  defp execute(:rebuild, schema, state, version, mapping, opts) do
    alias_name = state.alias
    old = state.live_physical
    new = "#{alias_name}_v#{version}"

    guard_existing_target!(alias_name, new, opts)

    :ok =
      Search.create_index!(schema,
        version: version,
        mapping: mapping,
        alias: false,
        meta: %{migration_started_at: DateTime.utc_now()}
      )

    # Wait until every node's write-target poll has observed the new index
    # and begun dual-writing, so no incremental document update is lost once
    # the bulk pass starts reading from the database.
    WriteTargets.refresh()
    Process.sleep(settle_ms(opts))

    Logger.info("#{alias_name}: bulk reindexing into #{new}")
    :ok = SearchIndexer.reindex_schema(schema, Keyword.put(reindex_opts(opts), :targets, [new]))

    {:ok, %{status: 200}} = Api.refresh_index(opensearch_url(), new)

    {:ok, %{status: 200}} =
      Api.update_aliases(opensearch_url(), %{
        actions: [
          %{remove: %{index: old, alias: alias_name}},
          %{add: %{index: new, alias: alias_name}}
        ]
      })

    Logger.info("#{alias_name}: now served by #{new}")

    # Nodes with stale write targets keep writing to the old index for up to
    # one poll interval; those writes 404 harmlessly while the copy to the
    # new index succeeds. The orphan list predates the guard above, so it may
    # name the leftover target this run replaced - never delete `new`.
    [old | state.orphans]
    |> Enum.uniq()
    |> Enum.reject(&(&1 == new))
    |> Enum.each(&delete_physical_index/1)

    WriteTargets.refresh()

    :ok
  end

  defp guard_existing_target!(alias_name, new, opts) do
    case Api.get_index(opensearch_url(), new) do
      {:ok, %{status: 404}} ->
        :ok

      {:ok, %{status: 200}} ->
        if not Keyword.get(opts, :force, false) and migration_in_progress?(new) do
          raise "Migration target #{new} for #{alias_name} already exists and was started " <>
                  "less than #{@stale_migration_hours}h ago - another migration run may be " <>
                  "active. Re-run with force: true to take it over."
        end

        Logger.warning("#{alias_name}: deleting leftover migration target #{new}")
        delete_physical_index(new)
    end
  end

  defp delete_orphans(%{orphans: []}, _opts), do: :ok

  defp delete_orphans(state, opts) do
    Enum.each(state.orphans, fn orphan ->
      if Keyword.get(opts, :force, false) or not migration_in_progress?(orphan) do
        Logger.info("#{state.alias}: deleting orphan index #{orphan}")
        delete_physical_index(orphan)
      else
        # Another run may be mid-rebuild into this index; leave it alone.
        Logger.warning("#{state.alias}: leaving fresh migration target #{orphan} in place")
      end
    end)
  end

  defp delete_physical_index(name) do
    {:ok, %{status: status}} = Api.delete_index(opensearch_url(), name)

    unless status in [200, 404] do
      raise "Could not delete search index #{name} (status #{status})"
    end

    :ok
  end

  defp migration_in_progress?(name) do
    with {:ok, %{status: 200, body: body}} <- Api.get_index(opensearch_url(), name),
         started when is_binary(started) <-
           get_in(body, [name, "mappings", "_meta", "migration_started_at"]),
         {:ok, started, _offset} <- DateTime.from_iso8601(started) do
      DateTime.diff(DateTime.utc_now(), started, :second) < @stale_migration_hours * 3600
    else
      _ -> false
    end
  end

  defp reindex_opts(opts) do
    Keyword.take(opts, [:maintenance, :max_concurrency])
  end

  defp settle_ms(opts) do
    Keyword.get(opts, :settle_ms) ||
      Application.get_env(:philomena, :search_migration_settle_ms, 15_000)
  end

  defp opensearch_url, do: SearchPolicy.opensearch_url()
end
