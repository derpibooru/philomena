defmodule Philomena.Search.Helpers do
  # Apparently, it's too hard for the standard library to to parse a number
  # as a float if it doesn't contain a decimal point. WTF
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

  def to_int(term) do
    {int, _} = :string.to_integer(term)

    case int in -2_147_483_648..2_147_483_647 do
      true -> int
      _false -> 0
    end
  end

  def range([center, deviation]) do
    [center - deviation, center + deviation]
  end
end
