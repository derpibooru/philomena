defmodule Textile.Lexer do
  import NimbleParsec
  import Textile.Helpers
  import Textile.MarkupLexer


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

  markup = markup_segment(eos())

  defparsec :markup, markup
end