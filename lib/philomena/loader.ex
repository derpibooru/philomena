defmodule Philomena.Loader do
  @moduledoc """
  Shared helpers for turning an id into a loaded record.

  Context functions repeatedly parse an id, load the record, and authorize the
  actor against it. These helpers capture that shape so it lives in one place.

  An id that no `integer` column could hold is `{:error, :not_found}` (via
  `Philomena.IntegerId.parse/1`).
  """

  import Ecto.Query, only: [preload: 2]
  import Philomena.Authorization, only: [authorize: 3]

  alias Philomena.Repo
  alias Philomena.IntegerId
  alias Philomena.Authorization

  @typedoc "Type of acceptable actor inputs."
  @type actor :: Authorization.actor()

  @typedoc "Type of acceptable integer ID inputs."
  @type integer_id :: IntegerId.integer_id()

  @typedoc "Generic type of fetch_and_authorize return value."
  @type fetch_and_authorize_result(t) :: {:ok, t} | {:error, :unauthorized | :not_found}

  @typedoc "Generic type of a load that does not perform authorization."
  @type fetch_result(t) :: {:ok, t} | {:error, :not_found}

  @typedoc "Errors shared by all authorized member loaders."
  @type load_error :: :unauthorized | :not_found

  @doc """
  Parses an integer ID, normalizing malformed or out-of-range values to
  `{:error, :not_found}`.

  ## Examples

      iex> parse_id("1234")
      {:ok, 1234}

      iex> parse_id("NaN")
      {:error, :not_found}

  """
  @spec parse_id(integer_id()) :: {:ok, integer()} | {:error, :not_found}
  def parse_id(id) do
    case IntegerId.parse(id) do
      {:ok, id} ->
        {:ok, id}

      :error ->
        {:error, :not_found}
    end
  end

  @doc """
  Loads the `queryable` record named by `id`, applying `preloads`, and authorizes
  `actor` for `action` on it.

  Parsing and loading happen before authorization. A malformed ID or absent row
  is therefore always `{:error, :not_found}`, independent of the actor. Only a
  real record can produce `{:error, :unauthorized}`.

  Returns `{:ok, record}`, `{:error, :unauthorized}`, or `{:error, :not_found}`.

  ## Examples

      iex> fetch_and_authorize(Channel, actor, :edit, "1")
      {:ok, %Channel{}}

      iex> fetch_and_authorize(Channel, actor, :edit, "not-a-number")
      {:error, :not_found}

  """
  @spec fetch_and_authorize(
          queryable :: Ecto.Queryable.t(),
          actor :: actor(),
          action :: atom(),
          id :: integer_id(),
          preloads :: list()
        ) :: fetch_and_authorize_result(struct())
  def fetch_and_authorize(queryable, actor, action, id, preloads \\ []) do
    with {:ok, record} <- fetch(queryable, id, preloads),
         :ok <- authorize(actor, action, record) do
      {:ok, record}
    end
  end

  @doc """
  Loads the `queryable` record named by `id`, applying `preloads`, with no
  authorization.

  A missing row, or an id that no `integer` column could hold, is
  `{:error, :not_found}`.

  Returns `{:ok, record}` or `{:error, :not_found}`.

  ## Examples

      iex> fetch(SubnetBan, "1")
      {:ok, %SubnetBan{}}

      iex> fetch(SubnetBan, "999999999")
      {:error, :not_found}

  """
  @spec fetch(
          queryable :: Ecto.Queryable.t(),
          id :: integer_id(),
          preloads :: list()
        ) ::
          fetch_result(struct())
  def fetch(queryable, id, preloads \\ []) do
    with {:ok, id} <- parse_id(id) do
      queryable
      |> preload(^preloads)
      |> Repo.get(id)
      |> case do
        nil ->
          {:error, :not_found}

        record ->
          {:ok, record}
      end
    end
  end

  @doc """
  Loads one record from `query` without authorization.

  This is the query-based counterpart to `fetch/3` for slugs, positions,
  composite keys, and parent-scoped resources. An empty result is
  `{:error, :not_found}`. If the query returns more than one row,
  `Ecto.MultipleResultsError` is raised because that violates the caller's
  one-record invariant.

  ## Examples

      iex> one(from rule in Rule, where: rule.position == 1)
      {:ok, %Rule{}}

      iex> one(from rule in Rule, where: rule.position == 999_999)
      {:error, :not_found}

  """
  @spec one(query :: Ecto.Queryable.t()) :: fetch_result(struct())
  def one(query) do
    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      record ->
        {:ok, record}
    end
  end

  @doc """
  Loads one record from `query`, then authorizes `actor` for `action` on it.

  An empty query result is always `{:error, :not_found}`. A loaded record the
  actor cannot access is `{:error, :unauthorized}`.

  ## Examples

      iex> one_and_authorize(from(rule in Rule, where: rule.position == 1), actor, :show)
      {:ok, %Rule{}}

      iex> one_and_authorize(from(rule in Rule, where: rule.position == 999_999), actor, :show)
      {:error, :not_found}

  """
  @spec one_and_authorize(
          query :: Ecto.Queryable.t(),
          actor :: actor(),
          action :: atom()
        ) :: fetch_and_authorize_result(struct())
  def one_and_authorize(query, actor, action) do
    with {:ok, record} <- one(query),
         :ok <- authorize(actor, action, record) do
      {:ok, record}
    end
  end
end
