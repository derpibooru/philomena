defmodule PhilomenaQuery.Search.WriteTargets do
  @moduledoc """
  Tracks which physical indices back each search index alias, so document
  writes can fan out to every live copy during an index migration.

  Physical indices are named `<alias>_v<version>`, and outside migrations
  exactly one of them holds the alias. While `Philomena.SearchMigrator`
  rebuilds an index, a second, not-yet-aliased physical index exists; writes
  must reach both copies so the new index is already complete when the alias
  is atomically swapped onto it.

  Each BEAM node polls `GET /_alias` every `:search_target_poll_interval_ms`
  and publishes the resulting groups via `:persistent_term`, making
  `targets_for/1` effectively free on the write path. Staleness is bounded by
  the poll interval; the migrator waits `:search_migration_settle_ms` (which
  must exceed the poll interval with margin) after creating the new index so
  every node dual-writes before the bulk reindex begins.
  """

  use GenServer

  alias PhilomenaQuery.Search.Api

  require Logger

  @policy Philomena.SearchPolicy

  @persistent_key {__MODULE__, :groups}
  @version_suffix ~r/\A(.+)_v\d+\z/

  @type group :: %{members: [String.t()], aliased: [String.t()]}
  @type groups :: %{String.t() => group()}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Return the index names a document write for `alias_name` must target.

  With a single physical index holding the alias (or a bare concrete index
  occupying the alias name), this is `[alias_name]`. With more than one
  member - a migration in progress - it is the physical index names, so
  writes land in every copy.

  If no state has been published yet, a synchronous refresh is performed
  rather than assuming `[alias_name]`, which could silently drop writes to a
  migration target.
  """
  @spec targets_for(String.t()) :: [String.t()]
  def targets_for(alias_name) do
    groups =
      case :persistent_term.get(@persistent_key, :missing) do
        :missing -> refresh()
        groups -> groups
      end

    case Map.get(groups, alias_name) do
      nil -> [alias_name]
      %{members: [single], aliased: [single]} -> [alias_name]
      %{members: [^alias_name]} -> [alias_name]
      %{members: members} -> members
    end
  end

  @doc """
  Synchronously refresh the published groups from the cluster and return them.

  Used by the migrator around index creation and swaps, and by tests for
  determinism. Concurrent callers serialize on the poller process.
  """
  @spec refresh() :: groups()
  def refresh do
    GenServer.call(__MODULE__, :refresh, 60_000)
  end

  @doc """
  Compute the group for `alias_name` from a `GET /_alias` response body.

  Members are: any index named `<alias_name>_v<digits>` (whether or not it
  currently holds the alias - a freshly created migration target is not yet
  aliased), any index whose aliases include `alias_name`, and a bare concrete
  index named exactly `alias_name` (the pre-migration state, or the result of
  a write auto-creating a missing index). `aliased` is the subset of members
  actually holding the alias.
  """
  @spec group(map(), String.t()) :: group()
  def group(aliases_body, alias_name) do
    Map.get(compute_groups(aliases_body), alias_name, %{members: [], aliased: []})
  end

  @impl true
  def init(_opts) do
    {:ok, nil, {:continue, :poll}}
  end

  @impl true
  def handle_continue(:poll, state) do
    publish()
    schedule_poll()

    {:noreply, state}
  end

  @impl true
  def handle_info(:poll, state) do
    publish()
    schedule_poll()

    {:noreply, state}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    {:reply, publish(), state}
  end

  defp schedule_poll do
    interval = Application.get_env(:philomena, :search_target_poll_interval_ms, 5_000)

    Process.send_after(self(), :poll, interval)
  end

  @spec publish() :: groups()
  defp publish do
    case Api.get_all_aliases(@policy.opensearch_url()) do
      {:ok, %{status: 200, body: body}} ->
        groups = compute_groups(body)

        # Only replace the persistent term when the groups actually changed,
        # as every replacement triggers a global GC.
        if :persistent_term.get(@persistent_key, :missing) != groups do
          :persistent_term.put(@persistent_key, groups)
        end

        groups

      error ->
        Logger.warning("Could not refresh search write targets: #{inspect(error)}")
        :persistent_term.get(@persistent_key, %{})
    end
  end

  @spec compute_groups(map()) :: groups()
  defp compute_groups(aliases_body) do
    aliases_body
    |> Enum.flat_map(fn {index_name, index_info} ->
      aliases = Map.get(index_info, "aliases", %{})

      name_group =
        case Regex.run(@version_suffix, index_name) do
          [_, group_name] -> group_name
          nil -> index_name
        end

      [name_group | Map.keys(aliases)]
      |> Enum.uniq()
      |> Enum.map(&{&1, index_name, Map.has_key?(aliases, &1)})
    end)
    |> Enum.group_by(&elem(&1, 0))
    |> Map.new(fn {group_name, entries} ->
      members = entries |> Enum.map(&elem(&1, 1)) |> Enum.sort()
      aliased = entries |> Enum.filter(&elem(&1, 2)) |> Enum.map(&elem(&1, 1)) |> Enum.sort()

      {group_name, %{members: members, aliased: aliased}}
    end)
  end
end
