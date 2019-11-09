defmodule Textile.TokenCoalescer do
  # The lexer, as a practical concern, does not coalesce runs of
  # character tokens. This fixes that.
  def coalesce_lex(tokens) do
    tokens
    |> Enum.chunk_by(&is_number(&1))
    |> Enum.flat_map(fn
      [t | _rest] = str when is_number(t) ->
        [text: List.to_string(str)]

      t ->
        t
    end)
  end

  def coalesce_parse(tokens) do
    tokens
    |> List.flatten()
    |> Enum.chunk_by(fn {k, _v} -> k == :text end)
    |> Enum.flat_map(fn t ->
      [{type, _v} | _rest] = t

      value =
        t
        |> Enum.map(fn {_k, v} -> v end)
        |> Enum.join("")

      [{type, value}]
    end)
  end
end