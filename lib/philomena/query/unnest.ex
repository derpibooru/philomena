defmodule Philomena.Query.Unnest do
  @moduledoc """
  Helpers for materializing values via Postgres `unnest`.

  This is useful when joins or inserts may otherwise exceed Postgres's normal
  65535-parameter limit:

      from entry in TagChangeTag,
        join: t in unnest(tuples, tag_change_id: :integer, tag_id: :integer),
        on: entry.tag_change_id == t.tag_change_id and entry.tag_id == t.tag_id

  """

  @doc """
  Materialize a list of tuples via a Postgres `unnest`.

  `tuples` must be a bound variable containing a list of tuples.

  `columns` must be a literal keyword list. It maps the ordered entries in
  `tuples` to Ecto types.

  See `m:Philomena.Query.Unnest` for examples.
  """
  defmacro unnest(tuples, columns) do
    if not match?({var, _, ctx} when is_atom(var) and is_atom(ctx), tuples) do
      raise ArgumentError, "tuples must be a variable"
    end

    columns
    |> Enum.with_index()
    |> Enum.map(fn {{_name, type}, index} ->
      quote do
        type(^Enum.map(unquote(tuples), &elem(&1, unquote(index))), {:array, unquote(type)})
      end
    end)
    |> __emit_unnest__(columns)
  end

  @doc """
  Materialize a list of maps via a Postgres `unnest`.

  `maps` must be a bound variable containing a list of maps.

  `columns` must be a literal keyword list. It maps the keys in `maps` to Ecto
  types.

  See `m:Philomena.Query.Unnest` for examples.
  """
  defmacro unnest_maps(maps, columns) do
    if not match?({var, _, ctx} when is_atom(var) and is_atom(ctx), maps) do
      raise ArgumentError, "maps must be a variable"
    end

    columns
    |> Enum.map(fn {name, type} ->
      quote do
        type(^Enum.map(unquote(maps), &Map.fetch!(&1, unquote(name))), {:array, unquote(type)})
      end
    end)
    |> __emit_unnest__(columns)
  end

  @doc false
  @spec __emit_unnest__([Macro.t()], Keyword.t()) :: Macro.t()
  def __emit_unnest__(spliced_columns, columns) do
    if not Keyword.keyword?(columns) or columns == [] do
      raise ArgumentError, "columns must be a non-empty keyword list"
    end

    column_placeholders = Enum.map_join(columns, ", ", fn _ -> "?" end)

    column_identifiers =
      Enum.map(columns, fn {name, _type} ->
        quote do
          identifier(^unquote(to_string(name)))
        end
      end)

    quote do
      fragment(
        "SELECT * FROM unnest(?) AS t(?)",
        splice([unquote_splicing(spliced_columns)]),
        fragment(unquote(column_placeholders), unquote_splicing(column_identifiers))
      )
    end
  end
end
