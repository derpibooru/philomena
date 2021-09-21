defmodule Philomena.Textile.Lexer do
  import NimbleParsec

  token_list =
    Enum.to_list(0x01..0x29) ++
      Enum.to_list(0x2B..0x2F) ++
      ':;<=>?[]\\^`~|'

  space_list = '\f \r\t\u00a0\u1680\u180e\u202f\u205f\u3000' ++ Enum.to_list(0x2000..0x200A)
  space = utf8_char(space_list)

  extended_space =
    choice([
      space,
      string("\n"),
      eos()
    ])

  space_token =
    space
    |> unwrap_and_tag(:space)

  double_newline =
    string("\n")
    |> repeat(space)
    |> string("\n")
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:double_newline)

  newline =
    string("\n")
    |> unwrap_and_tag(:newline)

  link_ending_characters = utf8_char('@#$%&(),.:;<=?\\`|\'')

  bracket_link_ending_characters = utf8_char('" []')

  end_of_link =
    choice([
      concat(link_ending_characters, extended_space),
      string("[/"),
      extended_space
    ])

  bracketed_literal =
    ignore(string("[=="))
    |> repeat(lookahead_not(string("==]")) |> utf8_char([]))
    |> ignore(string("==]"))

  unbracketed_literal =
    ignore(string("=="))
    |> repeat(lookahead_not(string("==")) |> utf8_char([]))
    |> ignore(string("=="))

  literal =
    choice([
      bracketed_literal,
      unbracketed_literal
    ])
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:literal)

  bq_cite_start =
    string("[bq=\"")
    |> unwrap_and_tag(:bq_cite_start)

  bq_cite_open =
    string("\"]")
    |> unwrap_and_tag(:bq_cite_open)

  bq_open =
    string("[bq]")
    |> unwrap_and_tag(:bq_open)

  bq_close =
    string("[/bq]")
    |> unwrap_and_tag(:bq_close)

  spoiler_open =
    string("[spoiler]")
    |> unwrap_and_tag(:spoiler_open)

  spoiler_close =
    string("[/spoiler]")
    |> unwrap_and_tag(:spoiler_close)

  image_url_scheme =
    choice([
      string("//"),
      string("/"),
      string("https://"),
      string("http://")
    ])

  link_url_scheme =
    choice([
      string("#"),
      image_url_scheme
    ])

  defparsec(
    :unbracketed_url_inside,
    choice([
      string("(") |> parsec(:unbracketed_url_inside) |> string(")"),
      lookahead_not(end_of_link) |> utf8_char([])
    ])
    |> repeat()
  )

  unbracketed_url =
    string(":")
    |> concat(link_url_scheme)
    |> parsec(:unbracketed_url_inside)

  unbracketed_image_url =
    unbracketed_url
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:unbracketed_image_url)

  unbracketed_link_url =
    string("\"")
    |> concat(unbracketed_url)
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:unbracketed_link_url)

  unbracketed_image =
    ignore(string("!"))
    |> concat(image_url_scheme)
    |> repeat(utf8_char(not: ?!))
    |> ignore(string("!"))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:unbracketed_image)
    |> concat(optional(unbracketed_image_url))

  bracketed_image =
    ignore(string("[!"))
    |> concat(image_url_scheme)
    |> repeat(lookahead_not(string("!]")) |> utf8_char([]))
    |> ignore(string("!]"))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:bracketed_image)
    |> concat(optional(unbracketed_image_url))

  link_delim =
    string("\"")
    |> unwrap_and_tag(:link_delim)

  bracketed_link_open =
    string("[\"")
    |> unwrap_and_tag(:bracketed_link_open)

  bracketed_link_url =
    string("\":")
    |> concat(link_url_scheme)
    |> repeat(lookahead_not(bracket_link_ending_characters) |> utf8_char([]))
    |> ignore(string("]"))
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:bracketed_link_url)

  bracketed_b_open = string("[**") |> unwrap_and_tag(:bracketed_b_open)
  bracketed_i_open = string("[__") |> unwrap_and_tag(:bracketed_i_open)
  bracketed_strong_open = string("[*") |> unwrap_and_tag(:bracketed_strong_open)
  bracketed_em_open = string("[_") |> unwrap_and_tag(:bracketed_em_open)
  bracketed_code_open = string("[@") |> unwrap_and_tag(:bracketed_code_open)
  bracketed_ins_open = string("[+") |> unwrap_and_tag(:bracketed_ins_open)
  bracketed_sup_open = string("[^") |> unwrap_and_tag(:bracketed_sup_open)
  bracketed_del_open = string("[-") |> unwrap_and_tag(:bracketed_del_open)
  bracketed_sub_open = string("[~") |> unwrap_and_tag(:bracketed_sub_open)

  bracketed_b_close = string("**]") |> unwrap_and_tag(:bracketed_b_close)
  bracketed_i_close = string("__]") |> unwrap_and_tag(:bracketed_i_close)
  bracketed_strong_close = string("*]") |> unwrap_and_tag(:bracketed_strong_close)
  bracketed_em_close = string("_]") |> unwrap_and_tag(:bracketed_em_close)
  bracketed_code_close = string("@]") |> unwrap_and_tag(:bracketed_code_close)
  bracketed_ins_close = string("+]") |> unwrap_and_tag(:bracketed_ins_close)
  bracketed_sup_close = string("^]") |> unwrap_and_tag(:bracketed_sup_close)
  bracketed_del_close = string("-]") |> unwrap_and_tag(:bracketed_del_close)
  bracketed_sub_close = string("~]") |> unwrap_and_tag(:bracketed_sub_close)

  b_delim = string("**") |> unwrap_and_tag(:b_delim)
  i_delim = string("__") |> unwrap_and_tag(:i_delim)
  strong_delim = string("*") |> unwrap_and_tag(:strong_delim)
  em_delim = string("_") |> unwrap_and_tag(:em_delim)
  code_delim = string("@") |> unwrap_and_tag(:code_delim)
  ins_delim = string("+") |> unwrap_and_tag(:ins_delim)
  sup_delim = lookahead_not(string("^"), string("^")) |> unwrap_and_tag(:sup_delim)
  sub_delim = string("~") |> unwrap_and_tag(:sub_delim)

  del_delim =
    lookahead_not(string("-"), choice([string("-"), string(">")])) |> unwrap_and_tag(:del_delim)

  quicktxt =
    utf8_char(Enum.map(space_list ++ token_list ++ '\n', fn c -> {:not, c} end))
    |> unwrap_and_tag(:quicktxt)

  char =
    utf8_char([])
    |> unwrap_and_tag(:char)

  textile =
    choice([
      literal,
      double_newline,
      newline,
      space_token,
      bq_cite_start,
      bq_cite_open,
      bq_open,
      bq_close,
      spoiler_open,
      spoiler_close,
      unbracketed_image,
      bracketed_image,
      bracketed_link_open,
      bracketed_link_url,
      unbracketed_link_url,
      link_delim,
      bracketed_b_open,
      bracketed_i_open,
      bracketed_strong_open,
      bracketed_em_open,
      bracketed_code_open,
      bracketed_ins_open,
      bracketed_sup_open,
      bracketed_del_open,
      bracketed_sub_open,
      bracketed_b_close,
      bracketed_i_close,
      bracketed_strong_close,
      bracketed_em_close,
      bracketed_code_close,
      bracketed_ins_close,
      bracketed_sup_close,
      bracketed_del_close,
      bracketed_sub_close,
      b_delim,
      i_delim,
      strong_delim,
      em_delim,
      code_delim,
      ins_delim,
      sup_delim,
      del_delim,
      sub_delim,
      quicktxt,
      char
    ])
    |> repeat()
    |> eos()

  defparsec(:lex, textile)
end
