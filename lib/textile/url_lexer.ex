defmodule Textile.UrlLexer do
  import NimbleParsec

  def url_ending_in(ending_sequence) do
    domain_character =
      choice([
        ascii_char([?a..?z]),
        ascii_char([?A..?Z]),
        ascii_char([?0..?9]),
        string("-")
      ])

    domain =
      repeat(
        choice([
          domain_character |> string(".") |> concat(domain_character),
          domain_character
        ])
      )

    scheme_and_domain =
      choice([
        string("#"),
        string("/"),
        string("data:image/"),
        string("https://") |> concat(domain),
        string("http://") |> concat(domain)
      ])

    scheme_and_domain
    |> repeat(lookahead_not(ending_sequence) |> utf8_char([]))
    |> reduce({List, :to_string, []})
  end
end