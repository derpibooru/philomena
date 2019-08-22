defmodule Philomena.Search.Lexer do
  import NimbleParsec

  defp to_number(term) do
    {float_val, _} = :string.to_float(term)
    {int_val, _} = :string.to_integer(term)

    cond do
      is_float(float_val) ->
        float_val
      is_integer(int_val) ->
        int_val
    end
  end

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

  number =
    optional(ascii_char('-+'))
    |> ascii_char([?0..?9])
    |> times(min: 1)
    |> optional(ascii_char('.') |> ascii_char([?0..?9]) |> times(min: 1))
    |> reduce(:to_number)

  boost = ignore(string("^")) |> unwrap_and_tag(number, :boost)
  fuzz = ignore(string("~")) |> unwrap_and_tag(number, :fuzz)

  space =
    choice([string(" "), string("\t"), string("\n"), string("\r"), string("\v"), string("\f")])
    |> ignore()

  quot = string("\"")

  quoted_term = 
    ignore(quot)
    |> choice([
      ignore(string("\\")) |> string("\""),
      ignore(string("\\")) |> string("\\"),
      string("\\") |> utf8_char([]),
      utf8_char(not: ?")
    ])
    |> times(min: 1)
    |> ignore(quot)
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:term)

  stop_words = choice([
    string("\\") |> eos(),
    string(","),
    concat(space, l_and),
    concat(space, l_or),
    concat(space, l_not),
    rparen,
    fuzz,
    boost
  ])

  defcombinatorp :simple_term,
    lookahead_not(stop_words)
    |> choice([
      string("\\") |> utf8_char([]),
      string("(") |> parsec(:simple_term) |> string(")"),
      utf8_char([]),
    ])
    |> times(min: 1)

  unquoted_term =
    parsec(:simple_term)
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:term)

  outer = choice([
    l_and,
    l_or,
    l_not,
    lparen,
    rparen,
    boost,
    fuzz,
    space,
    quoted_term,
    unquoted_term
  ])

  search =
    times(outer, min: 1)
    |> eos()

  defparsec :search, search
end