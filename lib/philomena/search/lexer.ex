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

  space =
    choice([string(" "), string("\t"), string("\n"), string("\r"), string("\v"), string("\f")])
    |> ignore()

  number =
    optional(ascii_char('-+'))
    |> ascii_char([?0..?9])
    |> times(min: 1)
    |> optional(ascii_char('.') |> ascii_char([?0..?9]) |> times(min: 1))
    |> reduce(:to_number)

  bool =
    choice([
      string("true"),
      string("false")
    ])
    |> reduce({Jason, :decode!, []})

  ipv4_octet =
    ascii_string([?0..?9], min: 1, max: 3)

  ipv4_mask =
    string("/")
    |> ascii_string([?0..?9], min: 1, max: 2)

  ipv4_address =
    concat(ipv4_octet, string("."))
    |> concat(ipv4_octet)
    |> string(".")
    |> concat(ipv4_octet)
    |> string(".")
    |> concat(ipv4_octet)

  ipv4_cidr =
    concat(ipv4_address, optional(ipv4_mask))

  ipv6_hexadectet =
    ascii_string('0123456789abcdefABCDEF', min: 1, max: 4)

  ipv6_mask =
    string("/")
    |> ascii_string([?0..?9], min: 1, max: 3)

  ipv4_mapped_ipv6 =
    string("::ffff:")
    |> concat(ipv4_address)

  # ipv6_address = # todo

  year = integer(4)
  month = integer(2)
  day = integer(2)
  
  hour = integer(2)
  minute = integer(2)
  second = integer(2)
  tz_hour = integer(2)
  tz_minute = integer(2)

  ymd_sep = ignore(string("-"))
  hms_sep = ignore(string(":"))
  iso8601_sep = ignore(choice([string("T"), string("t"), space]))
  iso8601_tzsep =
    choice([
      string("+") |> replace(1),
      string("-") |> replace(-1)
    ])
  zulu = ignore(choice([string("Z"), string("z")]))

  date_part =
    year
    |> optional(
      ymd_sep
      |> concat(month)
      |> optional(
        ymd_sep
        |> concat(day)
        |> optional(
          iso8601_sep
          |> optional(
            hour
            |> optional(
              hms_sep
              |> concat(minute)
              |> optional(
                concat(hms_sep, second)
              )
            )
          )
        )
      )
    )
    |> tag(:date)

  timezone_part =
    choice([
      iso8601_tzsep
      |> concat(tz_hour)
      |> optional(
        hms_sep
        |> concat(tz_minute)
      )
      |> tag(:timezone),
      zulu
    ])

  absolute_date =
    date_part
    |> optional(timezone_part)
    |> tag(:absolute_date)

  relative_date =
    integer(min: 1)
    |> ignore(concat(space, empty()))
    |> choice([
      string("second") |> optional(string("s")) |> replace(1),
      string("minute") |> optional(string("s")) |> replace(60),
      string("hour") |> optional(string("s")) |> replace(3600),
      string("day") |> optional(string("s")) |> replace(86400),
      string("week") |> optional(string("s")) |> replace(604800),
      string("month") |> optional(string("s")) |> replace(2629746),
      string("year") |> optional(string("s")) |> replace(31556952)
    ])
    |> ignore(string(" ago"))
    |> tag(:relative_date)

  date =
    choice([
      absolute_date,
      relative_date
    ])

  boost = ignore(string("^")) |> unwrap_and_tag(number, :boost)
  fuzz = ignore(string("~")) |> unwrap_and_tag(number, :fuzz)

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

  stop_words =
    choice([
      string("\\") |> eos(),
      string(","),
      concat(space, l_and),
      concat(space, l_or),
      concat(space, l_not),
      rparen,
      fuzz,
      boost
    ])

  defcombinatorp(
    :simple_term,
    lookahead_not(stop_words)
    |> choice([
      string("\\") |> utf8_char([]),
      string("(") |> parsec(:simple_term) |> string(")"),
      utf8_char([])
    ])
    |> times(min: 1)
  )

  unquoted_term =
    parsec(:simple_term)
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:term)

  outer =
    choice([
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

  defparsec(:search, search)
end
