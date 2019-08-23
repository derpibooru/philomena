defmodule Philomena.Search.Lexer do
  import NimbleParsec
  import Philomena.Search.Helpers

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

  int =
    integer(min: 1)
    |> label("an integer, such as `-100' or `5'")

  number =
    optional(ascii_char('-+'))
    |> ascii_char([?0..?9])
    |> times(min: 1)
    |> optional(ascii_char('.') |> ascii_char([?0..?9]) |> times(min: 1))
    |> label("a real number, such as `-2.71828' or `10'")
    |> reduce(:to_number)

  bool =
    choice([
      string("true"),
      string("false")
    ])
    |> label("a boolean, such as `false'")
    |> reduce({Jason, :decode!, []})

  ipv4_octet =
    choice([
      ascii_char('2') |> ascii_char('5') |> ascii_char([?0..?5]),
      ascii_char('2') |> ascii_char([?0..?4]) |> ascii_char([?0..?9]),
      ascii_char('1') |> ascii_char([?0..?9]) |> ascii_char([?0..?9]),
      ascii_char([?1..?9]) |> ascii_char([?0..?9]),
      ascii_char([?0..?9])
    ])
    |> reduce({List, :to_string, []})

  ipv4_address =
    times(ipv4_octet |> string("."), 3)
    |> concat(ipv4_octet)

  ipv4_prefix =
    ascii_char('/')
    |> choice([
      ascii_char('3') |> ascii_char([?0..?2]),
      ascii_char([?1..?2]) |> ascii_char([?0..?9]),
      ascii_char([?0..?9])
    ])
    |> reduce({List, :to_string, []})

  ipv6_hexadectet =
    ascii_string('0123456789abcdefABCDEF', min: 1, max: 4)

  ipv6_ls32 =
    choice([
      ipv6_hexadectet |> string(":") |> concat(ipv6_hexadectet),
      ipv4_address
    ])

  ipv6_fragment =
    ipv6_hexadectet |> string(":")

  ipv6_address =
    choice([
      times(ipv6_fragment, 6) |> concat(ipv6_ls32),
      string("::") |> times(ipv6_fragment, 5) |> concat(ipv6_ls32),

      ipv6_hexadectet |> string("::") |> times(ipv6_fragment, 4) |> concat(ipv6_ls32),
      string("::") |> times(ipv6_fragment, 4) |> concat(ipv6_ls32),
      
      times(ipv6_fragment, 1) |> concat(ipv6_hexadectet) |> string("::") |> times(ipv6_fragment, 3) |> concat(ipv6_ls32),
      ipv6_hexadectet |> string("::") |> times(ipv6_fragment, 3) |> concat(ipv6_ls32),
      string("::") |> times(ipv6_fragment, 3) |> concat(ipv6_ls32),

      times(ipv6_fragment, 2) |> concat(ipv6_hexadectet) |> string("::") |> times(ipv6_fragment, 2) |> concat(ipv6_ls32),
      times(ipv6_fragment, 1) |> concat(ipv6_hexadectet) |> string("::") |> times(ipv6_fragment, 2) |> concat(ipv6_ls32),
      ipv6_hexadectet |> string("::") |> times(ipv6_fragment, 2) |> concat(ipv6_ls32),
      string("::") |> times(ipv6_fragment, 2) |> concat(ipv6_ls32),

      times(ipv6_fragment, 3) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_fragment) |> concat(ipv6_ls32),
      times(ipv6_fragment, 2) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_fragment) |> concat(ipv6_ls32),
      times(ipv6_fragment, 1) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_fragment) |> concat(ipv6_ls32),
      ipv6_hexadectet |> string("::") |> concat(ipv6_fragment) |> concat(ipv6_ls32),
      string("::") |> concat(ipv6_fragment) |> concat(ipv6_ls32),

      times(ipv6_fragment, 4) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_ls32),
      times(ipv6_fragment, 3) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_ls32),
      times(ipv6_fragment, 2) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_ls32),
      times(ipv6_fragment, 1) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_ls32),
      ipv6_hexadectet |> string("::") |> concat(ipv6_ls32),
      string("::") |> concat(ipv6_ls32),

      times(ipv6_fragment, 5) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_hexadectet),
      times(ipv6_fragment, 4) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_hexadectet),
      times(ipv6_fragment, 3) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_hexadectet),
      times(ipv6_fragment, 2) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_hexadectet),
      times(ipv6_fragment, 1) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_hexadectet),
      ipv6_hexadectet |> string("::") |> concat(ipv6_hexadectet),
      string("::") |> concat(ipv6_hexadectet),

      times(ipv6_fragment, 6) |> concat(ipv6_hexadectet) |> string("::"),
      times(ipv6_fragment, 5) |> concat(ipv6_hexadectet) |> string("::"),
      times(ipv6_fragment, 4) |> concat(ipv6_hexadectet) |> string("::"),
      times(ipv6_fragment, 3) |> concat(ipv6_hexadectet) |> string("::"),
      times(ipv6_fragment, 2) |> concat(ipv6_hexadectet) |> string("::"),
      times(ipv6_fragment, 1) |> concat(ipv6_hexadectet) |> string("::"),
      ipv6_hexadectet |> string("::"),
      string("::")
    ])

  ipv6_prefix =
    ascii_char('/')
    |> choice([
      ascii_char('1') |> ascii_char('2') |> ascii_char([?0..?8]),
      ascii_char('1') |> ascii_char([?0..?1]) |> ascii_char([?0..?9]),
      ascii_char([?1..?9]) |> ascii_char([?0..?9]),
      ascii_char([?0..?9])
    ])
    |> reduce({List, :to_string, []})

  ip_address =
    choice([
      ipv4_address |> optional(ipv4_prefix),
      ipv6_address |> optional(ipv6_prefix)
    ])
    |> reduce({Enum, :join, []})
    |> label("a valid IPv4 or IPv6 address and optional CIDR prefix")
    |> unwrap_and_tag(:ip)

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
    |> label("an RFC3339 date and optional time, such as `2019-08-01'")
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
    |> label("a relative date, such as `3 days ago'")
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
