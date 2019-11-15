defmodule Search.IntParser do
  import NimbleParsec
  import Search.Helpers

  space =
    choice([string(" "), string("\t"), string("\n"), string("\r"), string("\v"), string("\f")])
    |> ignore()

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
    |> repeat(space)
    |> eos()
    |> label("an integer, like `3' or `-10'")

  defparsec :parse, int_parser
end