defmodule PhilomenaQuery.Parse.BoolParser do
  @moduledoc false

  import NimbleParsec

  space =
    choice([string(" "), string("\t"), string("\n"), string("\r"), string("\v"), string("\f")])
    |> ignore()

  bool =
    choice([
      string("true"),
      string("false")
    ])
    |> repeat(space)
    |> unwrap_and_tag(:bool)
    |> eos()
    |> label("a boolean, like `true' or `false'")

  defparsec(:parse, bool)
end
