defmodule Textile.TokenCoalescer do
  # The lexer, as a practical concern, does not coalesce runs of
  # character tokens. This fixes that.
  def coalesce(tokens) do
    tokens
    |> Enum.chunk_by(&is_number(&1))
    |> Enum.flat_map(fn
      [t | _rest] = str when is_number(t) ->
        [text: List.to_string(str)]

      t ->
        t
    )
  end
end