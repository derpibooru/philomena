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

  def full_choice(combinator \\ empty(), choices)

  def full_choice(combinator, []) do
    combinator |> eos()
  end

  def full_choice(combinator, [choice]) do
    combinator |> concat(choice)
  end

  def full_choice(combinator, choices) do
    choice(combinator, choices)
  end
end