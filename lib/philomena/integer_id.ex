defmodule Philomena.IntegerId do
  @moduledoc """
  Parsing of an id that may be any value (e.g. a string) before it is used in a
  query.

  Interpolating an unparsed id into `where(id: ^id)` raises rather
  than returning no rows: `Ecto.Query.CastError` for a non-integer, and
  `DBConnection.EncodeError` for a value too large for the `integer` column.
  Callers use `parse/1` to turn both into an ordinary "no such row".
  """

  # Bounds of the Postgres `integer` (int4) columns these ids are stored in.
  @int_min -2_147_483_648
  @int_max 2_147_483_647

  @typedoc "Type of acceptable integer ID inputs."
  @type integer_id :: integer() | nonempty_binary()

  @doc """
  Parses an id that an `integer` column could hold.

  Accepts an integer, or a string that is entirely an integer literal. Returns
  `:error` for anything else, including values outside the column's range.

  ## Examples

      iex> Philomena.IntegerId.parse("42")
      {:ok, 42}

      iex> Philomena.IntegerId.parse("-1")
      {:ok, -1}

      iex> Philomena.IntegerId.parse("not-a-number")
      :error

      iex> Philomena.IntegerId.parse("99999999999999999999")
      :error

  """
  @spec parse(integer_id()) :: {:ok, integer()} | :error
  def parse(id)

  def parse(id) when is_integer(id) do
    if in_range?(id) do
      {:ok, id}
    else
      :error
    end
  end

  def parse(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} ->
        parse(int)

      _ ->
        :error
    end
  end

  def parse(_id), do: :error

  defp in_range?(id), do: id >= @int_min and id <= @int_max
end
