defmodule PhilomenaQuery.Parse.Helpers do
  @moduledoc false

  @min_int32 -2_147_483_648
  @max_int32 2_147_483_647

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
    {int, []} = :string.to_integer(term)

    clamp_to_int32(int)
  end

  def int_range([center, deviation]) do
    [clamp_to_int32(center - deviation), clamp_to_int32(center + deviation)]
  end

  def clamp_to_int32(int) when is_integer(int),
    do: min(max(int, @min_int32), @max_int32)

  def range([center, deviation]) do
    [center - deviation, center + deviation]
  end
end
