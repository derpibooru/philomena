defmodule Philomena.Search.IpParser do
  import NimbleParsec

  ipv4_octet =
    choice([
      ascii_char(~c"2") |> ascii_char(~c"5") |> ascii_char([?0..?5]),
      ascii_char(~c"2") |> ascii_char([?0..?4]) |> ascii_char([?0..?9]),
      ascii_char(~c"1") |> ascii_char([?0..?9]) |> ascii_char([?0..?9]),
      ascii_char([?1..?9]) |> ascii_char([?0..?9]),
      ascii_char([?0..?9])
    ])
    |> reduce({List, :to_string, []})

  ipv4_address =
    times(ipv4_octet |> string("."), 3)
    |> concat(ipv4_octet)

  ipv4_prefix =
    ascii_char(~c"/")
    |> choice([
      ascii_char(~c"3") |> ascii_char([?0..?2]),
      ascii_char([?1..?2]) |> ascii_char([?0..?9]),
      ascii_char([?0..?9])
    ])
    |> reduce({List, :to_string, []})

  ipv6_hexadectet = ascii_string(~c"0123456789abcdefABCDEF", min: 1, max: 4)

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
    ascii_char(~c"/")
    |> choice([
      ascii_char(~c"1") |> ascii_char(~c"2") |> ascii_char([?0..?8]),
      ascii_char(~c"1") |> ascii_char([?0..?1]) |> ascii_char([?0..?9]),
      ascii_char([?1..?9]) |> ascii_char([?0..?9]),
      ascii_char([?0..?9])
    ])
    |> reduce({List, :to_string, []})

  space =
    choice([string(" "), string("\t"), string("\n"), string("\r"), string("\v"), string("\f")])
    |> ignore()

  ip =
    choice([
      ipv4_address |> optional(ipv4_prefix),
      ipv6_address |> optional(ipv6_prefix)
    ])
    |> reduce({Enum, :join, []})
    |> repeat(space)
    |> unwrap_and_tag(:ip)
    |> eos()
    |> label("a valid IPv4 or IPv6 address and optional CIDR prefix")

  defparsec(:parse, ip)
end
