defmodule PhilomenaQuery.Parse.FloatParser do
  @moduledoc false

  import NimbleParsec

  fuzz =
    string("~")
    |> ignore()

  unsigned_float =
    ascii_string([?0..?9], min: 1)
    |> optional(ascii_char(~c".") |> ascii_string([?0..?9], min: 1))
    |> reduce({List, :to_string, []})
    |> reduce({PhilomenaQuery.Parse.Helpers, :to_number, []})

  float =
    optional(ascii_char(~c"-+"))
    |> ascii_string([?0..?9], min: 1)
    |> optional(ascii_char(~c".") |> ascii_string([?0..?9], min: 1))
    |> reduce({List, :to_string, []})
    |> reduce({PhilomenaQuery.Parse.Helpers, :to_number, []})

  float_parser =
    choice([
      float
      |> concat(fuzz)
      |> concat(unsigned_float)
      |> reduce({PhilomenaQuery.Parse.Helpers, :range, []})
      |> unwrap_and_tag(:float_range),
      float |> unwrap_and_tag(:float)
    ])
    |> eos()
    |> label("a real number, like `2.7182818' or `-10'")

  defparsec(:parse, float_parser)
end
