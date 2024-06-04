defmodule PhilomenaQuery.Batch do
  @moduledoc """
  Locking-reduced database batch operations.

  These operations are non-transactional by their very nature. This prevents inadvertent
  downtimes due to blocking, but can result in consistency errors in the database,
  and so should be used sparingly.

  They are best suited for when large numbers of rows can be expected to be processed,
  as doing so may otherwise result in Ecto timing out the query.
  """

  alias Philomena.Repo
  import Ecto.Query

  @type queryable :: any()

  @type batch_size :: {:batch_size, integer()}
  @type id_field :: {:id_field, atom()}
  @type batch_options :: [batch_size() | id_field()]

  @type record_batch_callback :: ([struct()] -> any())
  @type query_batch_callback :: ([Ecto.Query.t()] -> any())

  @doc """
  Execute a callback with lists of schema structures on a queryable,
  using batches to avoid locking.

  Valid options:
    * `batch_size` (integer) - the number of records to load per batch
    * `id_field` (atom) - the name of the field containing the ID

  ## Example

      queryable = from i in Image, where: i.image_width >= 1920

      cb = fn images ->
        Enum.each(images, &IO.inspect(&1.id))
      end

      PhilomenaQuery.Batch.record_batches(queryable, cb)

  """
  @spec record_batches(queryable(), batch_options(), record_batch_callback()) :: []
  def record_batches(queryable, opts \\ [], callback) do
    query_batches(queryable, opts, &callback.(Repo.all(&1)))
  end

  @doc """
  Execute a callback with bulk queries on a queryable, using batches to avoid locking.

  Valid options:
    * `batch_size` (integer) - the number of records to load per batch
    * `id_field` (atom) - the name of the field containing the ID

  > #### Info {: .info}
  >
  > If you are looking to receive schema structures (e.g., you are querying for `Image`s,
  > and you want to receive `Image` objects, then use `record_batches/3` instead.

  An `m:Ecto.Query` which selects all IDs in the current batch is passed into the callback
  during each invocation.

  ## Example

      queryable = from ui in ImageVote, where: ui.user_id == 1234

      opts = [id_field: :image_id]

      cb = fn bulk_query ->
        Repo.delete_all(bulk_query)
      end

      PhilomenaQuery.Batch.query_batches(queryable, opts, cb)

  """
  @spec query_batches(queryable(), batch_options(), query_batch_callback()) :: []
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
    |> Repo.all()
  end
end
