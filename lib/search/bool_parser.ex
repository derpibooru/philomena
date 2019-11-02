defmodule Search.BoolParser do
  import NimbleParsec

  bool =
    choice([
      string("true"),
      string("false")
    ])
    |> unwrap_and_tag(:bool)
    |> eos()

  defparsec :parse, bool
end