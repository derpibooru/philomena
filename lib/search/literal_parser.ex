defmodule Search.LiteralParser do
  import NimbleParsec

  defp trim([term]), do: String.trim(term)

  edit_distance =
    ignore(string("~"))
    |> integer(min: 1)
    |> unwrap_and_tag(:fuzz)
    |> eos()

  stopwords =
    choice([
      string("*"),
      string("?"),
      edit_distance
    ])

  normal =
    lookahead_not(stopwords)
    |> choice([
      ignore(string("\\")) |> utf8_char([]),
      utf8_char([])
    ])
    |> repeat()
    |> reduce({List, :to_string, []})
    |> reduce(:trim)
    |> unwrap_and_tag(:literal)
    |> optional(edit_distance)
    |> eos()

  # Runs of Kleene stars are coalesced.
  # Fuzzy search has no meaning in wildcard mode, so we ignore it.
  wildcard =
    lookahead_not(edit_distance)
    |> choice([
      ignore(string("\\")) |> utf8_char([]),
      string("*") |> ignore(repeat(string("*"))),
      utf8_char([])
    ])
    |> repeat()
    |> reduce({List, :to_string, []})
    |> reduce(:trim)
    |> unwrap_and_tag(:wildcard)
    |> ignore(optional(edit_distance))
    |> eos()

  literal =
    choice([
      normal,
      wildcard
    ])

  defparsec :parse, literal
end