defmodule Search.TermRangeParser do
  alias Search.LiteralParser
  alias Search.NgramParser

  # Unfortunately, we can't use NimbleParsec here. It requires
  # the compiler, and we're not in a macro environment.

  def parse(input, fields, {default_field, type}) do
    tokens =
      Enum.find_value(fields, fn {f, p} ->
        field(input, f, p)
      end)

    tokens || [{parser(type), default_field}, range: :eq, value: input]
  end

  defp parser(:term), do: LiteralParser
  defp parser(:ngram), do: NgramParser

  defp field(input, field_name, field_parser) do
    field_sz = byte_size(field_name)

    case input do
      <<^field_name::binary-size(field_sz), ":", value::binary>> ->
        [{field_parser, field_name}, range: :eq, value: String.trim(value)]

      <<^field_name::binary-size(field_sz), ".eq:", value::binary>> ->
        [{field_parser, field_name}, range: :eq, value: String.trim(value)]

      <<^field_name::binary-size(field_sz), ".gt:", value::binary>> ->
        [{field_parser, field_name}, range: :gt, value: String.trim(value)]

      <<^field_name::binary-size(field_sz), ".gte:", value::binary>> ->
        [{field_parser, field_name}, range: :gte, value: String.trim(value)]

      <<^field_name::binary-size(field_sz), ".lt:", value::binary>> ->
        [{field_parser, field_name}, range: :lt, value: String.trim(value)]

      <<^field_name::binary-size(field_sz), ".lte:", value::binary>> ->
        [{field_parser, field_name}, range: :lte, value: String.trim(value)]

      _ ->
        nil
    end
  end
end
