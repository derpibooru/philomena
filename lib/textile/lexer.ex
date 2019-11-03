defmodule Textile.Lexer do
  import NimbleParsec
  import Textile.Helpers
  import Textile.MarkupLexer
  import Textile.UrlLexer


  # Structural tags


  # Literals enclosed via [== ==]
  # Will never contain any markup
  bracketed_literal =
    ignore(string("[=="))
    |> repeat(lookahead_not(string("==]")) |> utf8_char([]))
    |> ignore(string("==]"))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:bracketed_literal)

  blockquote_cite =
    lookahead_not(string("\""))
    |> choice([
      bracketed_literal |> reduce(:unwrap),
      utf8_char([])
    ])
    |> repeat()

  # Blockquote opening tag with cite: [bq="the author"]
  # Cite can contain bracketed literals or text
  blockquote_open_cite =
    ignore(string("[bq=\""))
    |> concat(blockquote_cite)
    |> ignore(string("\"]"))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:blockquote_open_cite)

  # Blockquote opening tag
  blockquote_open =
    string("[bq]")
    |> unwrap_and_tag(:blockquote_open)

  # Blockquote closing tag
  blockquote_close =
    string("[/bq]")
    |> unwrap_and_tag(:blockquote_close)

  # Spoiler open tag
  spoiler_open =
    string("[spoiler]")
    |> unwrap_and_tag(:spoiler_open)

  # Spoiler close tag
  spoiler_close =
    string("[/spoiler]")
    |> unwrap_and_tag(:spoiler_close)


  # Images


  image_url_with_title =
    url_ending_in(string("("))
    |> unwrap_and_tag(:image_url)
    |> concat(
      ignore(string("("))
      |> repeat(utf8_char(not: ?)))
      |> ignore(string(")"))
      |> lookahead(string("!"))
      |> reduce({List, :to_string, []})
      |> unwrap_and_tag(:image_title)
    )

  image_url_without_title =
    url_ending_in(string("!"))
    |> unwrap_and_tag(:image_url)

  image_url =
    choice([
      image_url_with_title,
      image_url_without_title
    ])

  bracketed_image_with_link =
    ignore(string("[!"))
    |> concat(image_url)
    |> ignore(string("!:"))
    |> concat(
      url_ending_in(string("]"))
      |> unwrap_and_tag(:image_link_url)
    )

  bracketed_image_without_link =
    ignore(string("[!"))
    |> concat(image_url)
    |> ignore(string("!]"))

  image_with_link =
    ignore(string("!"))
    |> concat(image_url)
    |> ignore(string("!:"))
    |> concat(
      url_ending_in(space())
      |> unwrap_and_tag(:image_link_url)
    )

  image_without_link =
    ignore(string("!"))
    |> concat(image_url)
    |> ignore(string("!"))

  image =
    choice([
      bracketed_image_with_link,
      bracketed_image_without_link,
      image_with_link,
      image_without_link
    ])

  defparsec :image, image
end