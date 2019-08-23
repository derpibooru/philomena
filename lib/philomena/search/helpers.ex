defmodule Philomena.Search.Helpers do
  import NimbleParsec

  def to_number(term) do
    {float_val, _} = :string.to_float(term)
    {int_val, _} = :string.to_integer(term)

    cond do
      is_float(float_val) ->
        float_val

      is_integer(int_val) ->
        int_val
    end
  end

  def reverse_times(combinator \\ empty(), to_repeat, opts) do
    max = opts[:max]

    combinator
    |> choice((for x <- max..1, do: times(to_repeat, x)) ++ [empty()])
  end
end