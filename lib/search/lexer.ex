defmodule Search.Lexer do
  import NimbleParsec
  import Search.Helpers

  float =
    optional(ascii_char('-+'))
    |> ascii_string([?0..?9], min: 1)
    |> optional(ascii_char('.') |> ascii_string([?0..?9], min: 1))
    |> reduce({List, :to_string, []})
    |> reduce(:to_number)

  l_and =
    choice([string("AND"), string("&&"), string(",")])
    |> unwrap_and_tag(:and)

  l_or =
    choice([string("OR"), string("||")])
    |> unwrap_and_tag(:or)

  l_not =
    choice([string("NOT"), string("!"), string("-")])
    |> unwrap_and_tag(:not)

  lparen = string("(") |> unwrap_and_tag(:lparen)
  rparen = string(")") |> unwrap_and_tag(:rparen)

  space =
    choice([string(" "), string("\t"), string("\n"), string("\r"), string("\v"), string("\f")])
    |> ignore()

  quot = string("\"")

  boost =
    ignore(string("^"))
    |> concat(float)
    |> unwrap_and_tag(:boost)

  stop_words =
    repeat(space)
    |> choice([
      l_and,
      l_or,
      rparen,
      boost
    ])

  defcombinatorp(
    :dirty_text,
    lookahead_not(stop_words)
    |> choice([
      string("\\") |> utf8_char([]),
      string("(") |> parsec(:dirty_text) |> string(")"),
      utf8_char(not: ?(..?))
    ])
    |> times(min: 1)
  )

  text =
    parsec(:dirty_text)
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:term)
    |> label("a term, like `safe'")

  quoted_text =
    ignore(quot)
    |> repeat(choice([
      ignore(string("\\")) |> string("\""),
      ignore(string("\\")) |> string("\\"),
      string("\\") |> utf8_char([]),
      utf8_char(not: ?")
    ]))
    |> ignore(quot)
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:term)
    |> label(~s|a term enclosed in quotes, like `"/)^3^(\\\\"'|)

  term =
    choice([
      quoted_text,
      text
    ])

  outer =
    choice([
      l_and,
      l_or,
      l_not,
      lparen,
      rparen,
      boost,
      space,
      term
    ])

  search =
    repeat(outer)
    |> eos()

  defparsec :lex, search
end