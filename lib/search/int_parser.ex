defmodule Search.IntParser do
  import NimbleParsec
  import Search.Helpers

  fuzz =
    string("~")
    |> ignore()

  int =
    optional(ascii_char('-+'))
    |> ascii_string([?0..?9], min: 1)
    |> reduce({List, :to_string, []})
    |> reduce(:to_int)

  int_parser =
    choice([
      int |> concat(fuzz) |> integer(min: 1) |> reduce(:range) |> unwrap_and_tag(:int_range),
      int |> unwrap_and_tag(:int)
    ])
    |> eos()
    |> label("an integer, like `3' or `-10'")

  defparsec :parse, int_parser
end