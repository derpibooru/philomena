defmodule Textile.MarkupLexer do
  import NimbleParsec
  import Textile.Helpers

  # Markup tags

  def markup_ending_in(ending_sequence) do

    # The literal tag is special, because
    # 1. It needs to capture everything inside it as a distinct token.
    # 2. It can be surrounded by markup on all sides.
    # 3. If it successfully tokenizes, it will always be in the output.

    literal_open_stops =
      choice([
        space(),
        ending_sequence,
        string("=")
      ])

    literal_close_stops =
      lookahead_not(
        choice([
          ending_sequence,
          string("\n\n"),
          string("="),
          space() |> concat(string("="))
        ])
      )
      |> utf8_char([])

    literal =
      ignore(string("=="))
      |> lookahead_not(literal_open_stops)
      |> repeat(literal_close_stops)
      |> ignore(string("=="))
      |> reduce({List, :to_string, []})
      |> unwrap_and_tag(:literal)

    b_open         = markup_open_tag("**", "*", :b)
    i_open         = markup_open_tag("__", "*", :i)

    strong_open    = markup_open_tag("*", :strong)
    em_open        = markup_open_tag("_", :em)
    code_open      = markup_open_tag("@", :code)
    ins_open       = markup_open_tag("+", :ins)
    sup_open       = markup_open_tag("^", :sup)
    del_open       = markup_open_tag("-", :del)
    sub_open       = markup_open_tag("~", :sub)

    b_b_open       = markup_open_tag("[**", "*", :b_b)
    b_i_open       = markup_open_tag("[__", "_", :b_i)

    b_strong_open  = markup_open_tag("[*", "*", :b_strong)
    b_em_open      = markup_open_tag("[_", "_", :b_em)
    b_code_open    = markup_open_tag("[@", "@", :b_code)
    b_ins_open     = markup_open_tag("[+", "+", :b_ins)
    b_sup_open     = markup_open_tag("[^", "^", :b_sup)
    b_del_open     = markup_open_tag("[-", "-", :b_del)
    b_sub_open     = markup_open_tag("[~", "~", :b_sub)

    b_b_close      = string("**]") |> unwrap_and_tag(:b_b_close)
    b_i_close      = string("__]") |> unwrap_and_tag(:b_i_close)

    b_strong_close = string("*]") |> unwrap_and_tag(:b_strong_close)
    b_em_close     = string("_]") |> unwrap_and_tag(:b_em_close)
    b_code_close   = string("@]") |> unwrap_and_tag(:b_code_close)
    b_ins_close    = string("+]") |> unwrap_and_tag(:b_ins_close)
    b_sup_close    = string("^]") |> unwrap_and_tag(:b_sup_close)
    b_del_close    = string("-]") |> unwrap_and_tag(:b_del_close)
    b_sub_close    = string("~]") |> unwrap_and_tag(:b_sub_close)

    b_close        = string("**") |> unwrap_and_tag(:b_close)
    i_close        = string("__") |> unwrap_and_tag(:i_close)

    strong_close   = string("*") |> unwrap_and_tag(:strong_close)
    em_close       = string("_") |> unwrap_and_tag(:em_close)
    code_close     = string("@") |> unwrap_and_tag(:code_close)
    ins_close      = string("+") |> unwrap_and_tag(:ins_close)
    sup_close      = string("^") |> unwrap_and_tag(:sup_close)
    del_close      = string("-") |> unwrap_and_tag(:del_close)
    sub_close      = string("~") |> unwrap_and_tag(:sub_close)

    bracketed_markup_opening_tags =
      choice([
        b_b_open,
        b_i_open,
        b_strong_open,
        b_em_open,
        b_code_open,
        b_ins_open,
        b_sup_open,
        b_del_open,
        b_sub_open
      ])

    markup_opening_tags =
      choice([
        b_open,
        i_open,
        strong_open,
        em_open,
        code_open,
        ins_open,
        sup_open,
        del_open,
        sub_open
      ])

    bracketed_markup_closing_tags =
      choice([
        b_b_close,
        b_i_close,
        b_strong_close,
        b_em_close,
        b_code_close,
        b_ins_close,
        b_sup_close,
        b_del_close,
        b_sub_close,
      ])

    markup_closing_tags =
      choice([
        b_close,
        i_close,
        strong_close,
        em_close,
        code_close,
        ins_close,
        sup_close,
        del_close,
        sub_close
      ])

    markup_at_start =
      choice([
        markup_opening_tags,
        bracketed_markup_opening_tags
      ])

    markup_element =
      lookahead_not(ending_sequence)
      |> choice([
        literal,
        bracketed_markup_closing_tags,
        bracketed_markup_opening_tags |> lookahead_not(space()),
        special_characters() |> concat(markup_opening_tags),
        markup_closing_tags |> choice([special_characters(), ending_sequence]),
        utf8_char([])
      ])

    {markup_at_start, markup_element}
  end
end