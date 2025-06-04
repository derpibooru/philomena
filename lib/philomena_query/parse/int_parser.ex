defmodule PhilomenaQuery.Parse.IntParser do
  @moduledoc false

  import NimbleParsec

  fuzz =
    string("~")
    |> ignore()

  int =
    optional(ascii_char(~c"-+"))
    |> ascii_string([?0..?9], min: 1)
    |> reduce({List, :to_string, []})
    |> reduce({PhilomenaQuery.Parse.Helpers, :to_int, []})

  int_parser =
    choice([
      int
      |> concat(fuzz)
      |> integer(min: 1)
      |> reduce({PhilomenaQuery.Parse.Helpers, :int_range, []})
      |> unwrap_and_tag(:int_range),
      int |> unwrap_and_tag(:int)
    ])
    |> eos()
    |> label("a signed integer, like `3' or `-10'")

  defparsec(:parse, int_parser)
end
