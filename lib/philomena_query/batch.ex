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

  @typedoc """
  Represents an object which may be operated on via `m:Ecto.Query`.

  This could be a schema object (e.g. `m:Philomena.Images.Image`) or a fully formed query
  `from i in Image, where: i.hidden_from_users == false`.
  """
  @type queryable :: any()

  @type batch_size :: {:batch_size, integer()}
  @type id_field :: {:id_field, atom()}
  @type batch_options :: [batch_size() | id_field()]

  @doc """
  Stream schema structures on a queryable, using batches to avoid locking.

  Valid options:
    * `batch_size` (integer) - the number of records to load per batch
    * `id_field` (atom) - the name of the field containing the ID

  ## Example

      queryable = from i in Image, where: i.image_width >= 1920

      queryable
      |> PhilomenaQuery.Batch.record_batches()
      |> Enum.each(fn image -> IO.inspect(image.id) end)

  """
  @spec records(queryable(), batch_options()) :: Enumerable.t()
  def records(queryable, opts \\ []) do
    queryable
    |> query_batches(opts)
    |> Stream.flat_map(&Repo.all/1)
  end

  @doc """
  Stream lists of schema structures on a queryable, using batches to avoid
  locking.

  Valid options:
    * `batch_size` (integer) - the number of records to load per batch
    * `id_field` (atom) - the name of the field containing the ID

  ## Example

      queryable = from i in Image, where: i.image_width >= 1920

      cb = fn images ->
        Enum.each(images, &IO.inspect(&1.id))
      end

      queryable
      |> PhilomenaQuery.Batch.record_batches()
      |> Enum.each(cb)

  """
  @spec record_batches(queryable(), batch_options()) :: Enumerable.t()
  def record_batches(queryable, opts \\ []) do
    queryable
    |> query_batches(opts)
    |> Stream.map(&Repo.all/1)
  end

  @doc """
  Stream bulk queries on a queryable, using batches to avoid locking.

  Valid options:
    * `batch_size` (integer) - the number of records to load per batch
    * `id_field` (atom) - the name of the field containing the ID

  > #### Info {: .info}
  >
  > If you are looking to receive schema structures (e.g., you are querying for `Image`s,
  > and you want to receive `Image` objects, then use `record_batches/3` instead.

  `m:Ecto.Query` structs which select the IDs in each batch are streamed out.

  ## Example

      queryable = from ui in ImageVote, where: ui.user_id == 1234

      queryable
      |> PhilomenaQuery.Batch.query_batches(id_field: :image_id)
      |> Enum.each(fn batch_query -> Repo.delete_all(batch_query) end)

  """
  @spec query_batches(queryable(), batch_options()) :: Enumerable.t(Ecto.Query.t())
  def query_batches(queryable, opts \\ []) do
    id_field = Keyword.get(opts, :id_field, :id)

    Stream.unfold(
      load_ids(queryable, -1, opts),
      fn
        [] ->
          # Stop when no more results are produced
          nil

        ids ->
          # Process results and output next query
          output = where(queryable, [m], field(m, ^id_field) in ^ids)
          next_ids = load_ids(queryable, Enum.max(ids), opts)

          {output, next_ids}
      end
    )
  end

  defp load_ids(queryable, max_id, opts) do
    id_field = Keyword.get(opts, :id_field, :id)
    batch_size = Keyword.get(opts, :batch_size, 1000)

    queryable
    |> exclude(:order_by)
    |> exclude(:preload)
    |> exclude(:select)
    |> order_by(asc: ^id_field)
    |> where([m], field(m, ^id_field) > ^max_id)
    |> select([m], field(m, ^id_field))
    |> limit(^batch_size)
    |> Repo.all(timeout: 120_000)
  end
end
