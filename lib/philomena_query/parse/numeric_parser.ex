defmodule PhilomenaQuery.Parse.NumericParser do
  @moduledoc false

  import NimbleParsec

  numeric_parser =
    ascii_string([?0..?9], min: 1)
    |> reduce({List, :to_string, []})
    |> reduce({PhilomenaQuery.Parse.Helpers, :to_int, []})
    |> unwrap_and_tag(:numeric)
    |> eos()
    |> label("a numeric value, like `3' or `10'")

  defparsec(:parse, numeric_parser)
end
