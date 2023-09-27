defmodule Philomena.Search.LiteralParser do
  import NimbleParsec
  @dialyzer [:no_match, :no_unused]

  defp to_number(input), do: Philomena.Search.Helpers.to_number(input)

  float =
    ascii_string([?0..?9], min: 1)
    |> optional(ascii_char(~c".") |> ascii_string([?0..?9], min: 1))
    |> reduce({List, :to_string, []})
    |> reduce(:to_number)

  edit_distance =
    ignore(string("~"))
    |> concat(float)
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
    |> unwrap_and_tag(:wildcard)
    |> ignore(optional(edit_distance))
    |> eos()

  literal =
    choice([
      normal,
      wildcard
    ])

  defparsec(:parse, literal)
end
