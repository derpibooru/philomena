defmodule Textile.UrlLexer do
  import NimbleParsec

  def url_ending_in(ending_sequence) do
    protocol =
      choice([
        string("/"), string("https://"), string("http://"), string("data:image/")
      ])

    protocol
    |> repeat(lookahead_not(ending_sequence) |> utf8_char([]))
    |> reduce({List, :to_string, []})
  end
end