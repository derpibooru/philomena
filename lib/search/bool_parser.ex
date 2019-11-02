defmodule Search.BoolParser do
  import NimbleParsec

  bool =
    choice([
      string("true"),
      string("false")
    ])
    |> unwrap_and_tag(:bool)
    |> eos()
    |> label("a boolean, like `true' or `false'")

  defparsec :parse, bool
end