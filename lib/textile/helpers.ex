defmodule Textile.Helpers do
  import NimbleParsec

  # Helper to "undo" a tokenization and convert it back
  # to a string
  def unwrap([{_name, value}]), do: value

  # Lots of extra unicode space characters
  def space do
    choice([
      utf8_char('\n\r\f \t\u00a0\u1680\u180e\u202f\u205f\u3000'),
      utf8_char([0x2000..0x200a])
    ])
  end

  # Characters which are valid before and after the main markup characters.
  def special_characters do
    choice([
      space(),
      utf8_char('#$%&(),./:;<=?\\`|\'')
    ])
  end

  # Simple tag for a markup element that must
  # be succeeded immediately by a non-space character
  def markup_open_tag(str, char \\ nil, tag_name) do
    char = char || binary_head(str)

    open_stops =
      choice([
        space(),
        string(char)
      ])

    string(str)
    |> lookahead_not(open_stops)
    |> unwrap_and_tag(:"#{tag_name}_open")
  end

  defp binary_head(<<c::utf8, _rest::binary>>), do: <<c::utf8>>
end
