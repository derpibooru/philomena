defmodule Philomena.Batch do
  alias Philomena.Repo
  import Ecto.Query

  @doc """
  Load records from the given queryable in batches, to avoid locking.

  Valid options:
    * :batch_size
    * :id_field
  """
  def record_batches(queryable, opts \\ [], callback) do
    query_batches(queryable, opts, &callback.(Repo.all(&1)))
  end

  @doc """
  Load queries from the given queryable in batches, to avoid locking.

  Valid options:
    * :batch_size
    * :id_field
  """
  def query_batches(queryable, opts \\ [], callback) do
    ids = load_ids(queryable, -1, opts)

    query_batches(queryable, opts, callback, ids)
  end

  defp query_batches(_queryable, _opts, _callback, []), do: []

  defp query_batches(queryable, opts, callback, ids) do
    id_field = Keyword.get(opts, :id_field, :id)

    queryable
    |> where([m], field(m, ^id_field) in ^ids)
    |> callback.()

    ids = load_ids(queryable, Enum.max(ids), opts)

    query_batches(queryable, opts, callback, ids)
  end

  defp load_ids(queryable, max_id, opts) do
    id_field = Keyword.get(opts, :id_field, :id)
    batch_size = Keyword.get(opts, :batch_size, 1000)

    queryable
    |> exclude(:preload)
    |> exclude(:order_by)
    |> order_by(asc: ^id_field)
    |> where([m], field(m, ^id_field) > ^max_id)
    |> select([m], field(m, ^id_field))
    |> limit(^batch_size)
    |> Repo.all(timeout: 120_000)
  end
end
