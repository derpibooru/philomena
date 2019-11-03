defmodule Textile.Lexer do
  import NimbleParsec

  defp unwrap([{_name, value}]),
    do: value

  # Lots of extra unicode space characters
  space =
    choice([
      utf8_char('\n\r\f \t\u00a0\u1680\u180e\u202f\u205f\u3000'),
      utf8_char([0x2000..0x200a])
    ])

  bracketed_literal =
    ignore(string("[=="))
    |> repeat(lookahead_not(string("==]")) |> utf8_char([]))
    |> ignore(string("==]"))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:bracketed_literal)

  link_text_with_title =
    ignore(string("\""))
    |> times(utf8_char(not: ?(), min: 1)
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:link_text)
    |> ignore(string("("))
    |> concat(
      times(utf8_char(not: ?), not: ?"), min: 1)
      |> reduce({List, :to_string, []})
      |> unwrap_and_tag(:link_title)
      |> ignore(string(")\":"))
    )

  link_text_without_title =
    ignore(string("\""))
    |> times(utf8_char(not: ?"), min: 1)
    |> ignore(string("\":"))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:link_text)

  link_text =
    choice([
      link_text_with_title,
      link_text_without_title
    ])

  link_protocol =
    choice([
      string("/"), string("https://"), string("http://"), string("data:image/")
    ])

  uri_ending_at_space =
    link_protocol
    |> times(lookahead_not(space) |> utf8_char([]), min: 1)
    |> reduce({List, :to_string, []})

  uri_ending_at_bracket =
    link_protocol
    |> times(lookahead_not(string("]")) |> utf8_char([]), min: 1)
    |> reduce({List, :to_string, []})

  uri_ending_at_lparen =
    link_protocol
    |> times(lookahead_not(string("(")) |> utf8_char([]), min: 1)
    |> reduce({List, :to_string, []})

  uri_ending_at_bang =
    link_protocol
    |> times(lookahead_not(string("!")) |> utf8_char([]), min: 1)
    |> reduce({List, :to_string, []})

  unbracketed_link =
    link_text
    |> concat(uri_ending_at_space |> unwrap_and_tag(:link_url))

  bracketed_link =
    ignore(string("["))
    |> concat(link_text)
    |> concat(uri_ending_at_bracket |> unwrap_and_tag(:link_url))
    |> ignore(string("]"))

  link =
    choice([
      bracketed_link,
      unbracketed_link
    ])

  image_url_with_title =
    ignore(string("!"))
    |> concat(uri_ending_at_lparen |> unwrap_and_tag(:image_url))
    |> ignore(string("("))
    |> concat(
      times(utf8_char(not: ?), not: ?!), min: 1)
      |> reduce({List, :to_string, []})
      |> unwrap_and_tag(:image_title)
      |> ignore(string(")!"))
    )

  image_url_without_title =
    ignore(string("!"))
    |> concat(uri_ending_at_bang |> unwrap_and_tag(:image_url))
    |> ignore(string("!"))

  image_url =
    choice([
      image_url_with_title,
      image_url_without_title
    ])

  unbracketed_image =
    image_url
    |> optional(
      ignore(string(":"))
      |> concat(uri_ending_at_space)
      |> unwrap_and_tag(:image_link_url)
    )

  bracketed_image =
    ignore(string("["))
    |> concat(image_url)
    |> optional(
      ignore(string(":"))
      |> concat(uri_ending_at_bracket)
      |> unwrap_and_tag(:image_link_url)
    )
    |> ignore(string("]"))

  image =
    choice([
      bracketed_image,
      unbracketed_image
    ])

  literal =
    ignore(string("=="))
    |> repeat(lookahead_not(string("==")) |> utf8_char([]))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:literal)
    |> ignore(string("=="))

  blockquote_author =
    repeat(
      lookahead_not(string("\"]"))
      |> choice([
        bracketed_literal,
        literal,
        utf8_char([])
      ])
    )
    |> reduce(:unwrap)

  l_bq_author =
    ignore(string("[bq=\""))
    |> concat(blockquote_author)
    |> ignore(string("\"]"))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:l_bq_author)

  l_bq = string("[bq]") |> unwrap_and_tag(:l_bq)
  r_bq = string("[/bq]") |> unwrap_and_tag(:r_bq)

  l_spoiler = string("[spoiler]") |> unwrap_and_tag(:l_spoiler)
  r_spoiler = string("[/spoiler]") |> unwrap_and_tag(:r_spoiler)

  stop_words =
    choice([
      bracketed_literal,
      bracketed_link,
      bracketed_image,
      link,
      image,
      l_bq_author,
      l_bq,
      r_bq,
      l_spoiler,
      r_spoiler,
    ])

  defcombinatorp :top_level,
    choice([
      stop_words,
      times(lookahead_not(stop_words) |> utf8_char([]), min: 1)
      |> reduce({List, :to_string, []})
      |> unwrap_and_tag(:text)
    ])

  textile =
    repeat(parsec(:top_level))
    |> eos()

  defparsec :lex, textile
end