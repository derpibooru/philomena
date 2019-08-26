defmodule Philomena.Search.Lexer do
  defmacro __using__(opts) do
    literal_fields = Keyword.get(opts, :literal, []) |> Macro.expand(__CALLER__)
    ngram_fields = Keyword.get(opts, :ngram, []) |> Macro.expand(__CALLER__)
    bool_fields = Keyword.get(opts, :bool, []) |> Macro.expand(__CALLER__)
    date_fields = Keyword.get(opts, :date, []) |> Macro.expand(__CALLER__)
    float_fields = Keyword.get(opts, :float, []) |> Macro.expand(__CALLER__)
    int_fields = Keyword.get(opts, :int, []) |> Macro.expand(__CALLER__)
    ip_fields = Keyword.get(opts, :ip, []) |> Macro.expand(__CALLER__)
    custom_fields = Keyword.get(opts, :custom, []) |> Macro.expand(__CALLER__)

    quote location: :keep do
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
        optional(ascii_char('-+'))
        |> ascii_char([?0..?9])
        |> times(min: 1)
        |> reduce({List, :to_string, []})
        |> reduce(:to_number)
        |> unwrap_and_tag(:int)
        |> label("an integer, such as `-100' or `5'")

      number =
        optional(ascii_char('-+'))
        |> ascii_char([?0..?9])
        |> times(min: 1)
        |> optional(ascii_char('.') |> ascii_char([?0..?9]) |> times(min: 1))
        |> reduce({List, :to_string, []})
        |> reduce(:to_number)
        |> unwrap_and_tag(:number)
        |> label("a real number, such as `-2.71828' or `10'")

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

      ipv6_hexadectet = ascii_string('0123456789abcdefABCDEF', min: 1, max: 4)

      ipv6_ls32 =
        choice([
          ipv6_hexadectet |> string(":") |> concat(ipv6_hexadectet),
          ipv4_address
        ])

      ipv6_fragment = ipv6_hexadectet |> string(":")

      ipv6_address =
        choice([
          times(ipv6_fragment, 6) |> concat(ipv6_ls32),
          string("::") |> times(ipv6_fragment, 5) |> concat(ipv6_ls32),
          ipv6_hexadectet |> string("::") |> times(ipv6_fragment, 4) |> concat(ipv6_ls32),
          string("::") |> times(ipv6_fragment, 4) |> concat(ipv6_ls32),
          times(ipv6_fragment, 1)
          |> concat(ipv6_hexadectet)
          |> string("::")
          |> times(ipv6_fragment, 3)
          |> concat(ipv6_ls32),
          ipv6_hexadectet |> string("::") |> times(ipv6_fragment, 3) |> concat(ipv6_ls32),
          string("::") |> times(ipv6_fragment, 3) |> concat(ipv6_ls32),
          times(ipv6_fragment, 2)
          |> concat(ipv6_hexadectet)
          |> string("::")
          |> times(ipv6_fragment, 2)
          |> concat(ipv6_ls32),
          times(ipv6_fragment, 1)
          |> concat(ipv6_hexadectet)
          |> string("::")
          |> times(ipv6_fragment, 2)
          |> concat(ipv6_ls32),
          ipv6_hexadectet |> string("::") |> times(ipv6_fragment, 2) |> concat(ipv6_ls32),
          string("::") |> times(ipv6_fragment, 2) |> concat(ipv6_ls32),
          times(ipv6_fragment, 3)
          |> concat(ipv6_hexadectet)
          |> string("::")
          |> concat(ipv6_fragment)
          |> concat(ipv6_ls32),
          times(ipv6_fragment, 2)
          |> concat(ipv6_hexadectet)
          |> string("::")
          |> concat(ipv6_fragment)
          |> concat(ipv6_ls32),
          times(ipv6_fragment, 1)
          |> concat(ipv6_hexadectet)
          |> string("::")
          |> concat(ipv6_fragment)
          |> concat(ipv6_ls32),
          ipv6_hexadectet |> string("::") |> concat(ipv6_fragment) |> concat(ipv6_ls32),
          string("::") |> concat(ipv6_fragment) |> concat(ipv6_ls32),
          times(ipv6_fragment, 4) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_ls32),
          times(ipv6_fragment, 3) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_ls32),
          times(ipv6_fragment, 2) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_ls32),
          times(ipv6_fragment, 1) |> concat(ipv6_hexadectet) |> string("::") |> concat(ipv6_ls32),
          ipv6_hexadectet |> string("::") |> concat(ipv6_ls32),
          string("::") |> concat(ipv6_ls32),
          times(ipv6_fragment, 5)
          |> concat(ipv6_hexadectet)
          |> string("::")
          |> concat(ipv6_hexadectet),
          times(ipv6_fragment, 4)
          |> concat(ipv6_hexadectet)
          |> string("::")
          |> concat(ipv6_hexadectet),
          times(ipv6_fragment, 3)
          |> concat(ipv6_hexadectet)
          |> string("::")
          |> concat(ipv6_hexadectet),
          times(ipv6_fragment, 2)
          |> concat(ipv6_hexadectet)
          |> string("::")
          |> concat(ipv6_hexadectet),
          times(ipv6_fragment, 1)
          |> concat(ipv6_hexadectet)
          |> string("::")
          |> concat(ipv6_hexadectet),
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
      iso8601_tzsep = choice([string("+"), string("-")])
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
                  |> optional(concat(hms_sep, second))
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
        |> reduce(:absolute_datetime)
        |> unwrap_and_tag(:date)
        |> label("an RFC3339 date and optional time, such as `2019-08-01'")

      relative_date =
        integer(min: 1)
        |> ignore(concat(space, empty()))
        |> choice([
          string("second") |> optional(string("s")) |> replace(1),
          string("minute") |> optional(string("s")) |> replace(60),
          string("hour") |> optional(string("s")) |> replace(3600),
          string("day") |> optional(string("s")) |> replace(86400),
          string("week") |> optional(string("s")) |> replace(604_800),
          string("month") |> optional(string("s")) |> replace(2_592_000),
          string("year") |> optional(string("s")) |> replace(31_536_000)
        ])
        |> ignore(string(" ago"))
        |> reduce(:relative_datetime)
        |> unwrap_and_tag(:date)
        |> label("a relative date, such as `3 days ago'")

      date =
        choice([
          absolute_date,
          relative_date
        ])

      eq = choice([string(":"), string(".eq:")]) |> unwrap_and_tag(:eq)
      lt = string(".lt:") |> unwrap_and_tag(:lt)
      lte = string(".lte:") |> unwrap_and_tag(:lte)
      gt = string(".gt:") |> unwrap_and_tag(:gt)
      gte = string(".gte:") |> unwrap_and_tag(:gte)

      range_relation =
        choice([
          eq,
          lt,
          lte,
          gt,
          gte
        ])

      boost =
        string("^")
        |> unwrap_and_tag(:boost)
        |> concat(number)

      fuzz =
        string("~")
        |> unwrap_and_tag(:fuzz)
        |> concat(number)

      quot = string("\"")

      bool_value =
        full_choice(unquote(for f <- bool_fields, do: [string: f]))
        |> unwrap_and_tag(:bool_field)
        |> concat(eq)
        |> concat(bool)

      date_value =
        full_choice(unquote(for f <- date_fields, do: [string: f]))
        |> unwrap_and_tag(:date_field)
        |> concat(range_relation)
        |> concat(date)

      float_value =
        full_choice(unquote(for f <- float_fields, do: [string: f]))
        |> unwrap_and_tag(:float_field)
        |> concat(range_relation)
        |> concat(number)

      int_value =
        full_choice(unquote(for f <- int_fields, do: [string: f]))
        |> unwrap_and_tag(:int_field)
        |> concat(range_relation)
        |> concat(int)

      ip_value =
        full_choice(unquote(for f <- ip_fields, do: [string: f]))
        |> unwrap_and_tag(:ip_field)
        |> ignore(eq)
        |> concat(ip_address)

      numeric =
        choice([
          bool_value,
          date_value,
          float_value,
          int_value,
          ip_value
        ])

      quoted_numeric = ignore(quot) |> concat(numeric) |> ignore(quot)

      stop_words =
        choice([
          string("\\") |> eos(),
          string(","),
          concat(space, l_and),
          concat(space, l_or),
          rparen,
          fuzz,
          boost
        ])

      defcombinatorp(
        :text,
        lookahead_not(stop_words)
        |> choice([
          string("\\") |> utf8_char([]),
          string("(") |> parsec(:text) |> string(")"),
          utf8_char([])
        ])
        |> times(min: 1)
      )

      text =
        parsec(:text)
        |> reduce({List, :to_string, []})
        |> unwrap_and_tag(:text)

      quoted_text =
        choice([
          ignore(string("\\")) |> string("\""),
          ignore(string("\\")) |> string("\\"),
          string("\\") |> utf8_char([]),
          utf8_char(not: ?")
        ])
        |> times(min: 1)
        |> reduce({List, :to_string, []})
        |> unwrap_and_tag(:text)

      literal =
        full_choice(unquote(for f <- literal_fields, do: [string: f]))
        |> unwrap_and_tag(:literal_field)
        |> ignore(eq)
        |> concat(text)

      ngram =
        full_choice(unquote(for f <- ngram_fields, do: [string: f]))
        |> unwrap_and_tag(:ngram_field)
        |> ignore(eq)
        |> concat(text)

      custom =
        full_choice(unquote(for f <- custom_fields, do: [string: f]))
        |> unwrap_and_tag(:custom_field)
        |> ignore(string(":"))
        |> concat(text)

      quoted_literal =
        ignore(quot)
        |> full_choice(unquote(for f <- literal_fields, do: [string: f]))
        |> unwrap_and_tag(:literal_field)
        |> ignore(eq)
        |> concat(quoted_text)
        |> ignore(quot)

      quoted_ngram =
        ignore(quot)
        |> full_choice(unquote(for f <- ngram_fields, do: [string: f]))
        |> unwrap_and_tag(:ngram_field)
        |> ignore(eq)
        |> concat(quoted_text)
        |> ignore(quot)

      quoted_custom =
        ignore(quot)
        |> full_choice(unquote(for f <- custom_fields, do: [string: f]))
        |> unwrap_and_tag(:custom_field)
        |> ignore(string(":"))
        |> concat(quoted_text)
        |> ignore(quot)

      default =
        text
        |> tag(:default)

      quoted_default =
        ignore(quot)
        |> concat(quoted_text)
        |> ignore(quot)
        |> tag(:default)

      term =
        choice([
          quoted_numeric,
          quoted_literal,
          quoted_ngram,
          quoted_custom,
          quoted_default,
          numeric,
          literal,
          ngram,
          custom,
          default
        ])

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
          term
        ])

      search =
        times(outer, min: 1)
        |> eos()

      defparsec(:search, search)
    end
  end
end
