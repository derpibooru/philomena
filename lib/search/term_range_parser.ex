defmodule Search.TermRangeParser do
  alias Search.LiteralParser

  # Unfortunately, we can't use NimbleParsec here. It requires
  # the compiler, and we're not in a macro environment.

  def parse(input, fields, default_field) do
    tokens =
      Enum.find_value(fields, fn {f, p} ->
        field(input, f, p)
      end)

    tokens || [{LiteralParser, default_field}, range: :eq, value: input]
  end

  defp field(input, field_name, field_parser) do
    field_sz = byte_size(field_name)

    case input do
      <<^field_name::binary-size(field_sz), ":", value::binary>> ->
        [{field_parser, field_name}, range: :eq, value: value]
      <<^field_name::binary-size(field_sz), ".eq:", value::binary>> ->
        [{field_parser, field_name}, range: :eq, value: value]
      <<^field_name::binary-size(field_sz), ".gt:", value::binary>> ->
        [{field_parser, field_name}, range: :gt, value: value]
      <<^field_name::binary-size(field_sz), ".gte:", value::binary>> ->
        [{field_parser, field_name}, range: :gte, value: value]
      <<^field_name::binary-size(field_sz), ".lt:", value::binary>> ->
        [{field_parser, field_name}, range: :lt, value: value]
      <<^field_name::binary-size(field_sz), ".lte:", value::binary>> ->
        [{field_parser, field_name}, range: :lte, value: value]
      _ ->
        nil
    end
  end
end