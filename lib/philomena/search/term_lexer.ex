"""
defmodule Philomena.Search.TermLexer do
  def lex(opts, input) do
    {:ok | accept(opts, input, :literal)}
  #rescue
  #  e in ArgumentError ->
  #    {:error, e.message}
  #  _ ->
  #    {:error, "Parsing error."}
  end

  #
  # Literal fields
  #

  defp accept([field | r_fields], opts, input, :literal_field) do
    sz = field |> byte_size

    case input do
      <<^field::binary-size(sz), ":", rest::binary>> ->
        [{:literal_field, field} | accept(rest, :literal)]
      <<^field::binary-size(sz), ".eq:", rest::binary>> ->
        [{:literal_field, field} | accept(rest, :literal)]
      _ ->
        accept(r_fields, opts, input, :literal_field)
    end
  end
  defp accept([], %{boolean_fields: fields} = opts, input, :literal_field), do: accept(fields, opts, input, :boolean_field)

  #
  # Boolean fields
  #

  defp accept([field | r_fields], opts, input, :boolean_field) do
    sz = field |> byte_size

    case input do
      <<^field::binary-size(sz), ":", rest::binary>> ->
        [{:boolean_field, field} | accept(rest, :boolean)]
      <<^field::binary-size(sz), ".eq:", rest::binary>> ->
        [{:boolean_field, field} | accept(rest, :boolean)]
      _ ->
        accept(r_fields, opts, input, :boolean_field)
    end
  end
  defp accept([], %{ngram_fields: fields} = opts, input, :boolean_field), do: accept(fields, opts, input, :ngram_field)

  #
  # NLP-analyzed fields
  #

  defp accept([field | r_fields], opts, input, :ngram_field) do
    sz = field |> byte_size

    case input do
      <<^field::binary-size(sz), ":", rest::binary>> ->
        [{:ngram_field, field} | accept(rest, :literal)]
      <<^field::binary-size(sz), ".eq:", rest::binary>> ->
        [{:ngram_field, field} | accept(rest, :literal)]
      _ ->
        accept(r_fields, opts, input, :ngram_field)
    end
  end
  defp accept([], %{ip_fields: fields} = opts, input, :ngram_field), do: accept(fields, opts, input, :ip_fieldngram

  #
  # IP address and CIDR range fields
  #

  defp accept([field | r_fields], opts, input, :ip_field) do
    sz = field |> byte_size

    case input do
      <<^field::binary-size(sz), ":", rest::binary>> ->
        [{:ip_field, field} | accept(rest, :ip)]
      <<^field::binary-size(sz), ".eq:", rest::binary>> ->
        [{:ip_field, field} | accept(rest, :ip)]
      _ ->
        accept(r_fields, opts, input, :ip_field)
    end
  end
  defp accept([], %{int_fields: fields} = opts, input, :ip_field), do: accept(fields, opts, input, :int_field)

  #
  # Integer fields
  #

  defp accept([field | r_fields], opts, input, :int_field) do
    sz = field |> byte_size

    case input do
      <<^field::binary-size(sz), ":", rest::binary>> ->
        [{:int_field, field}, {:range, :eq} | accept(rest, :int)]
      <<^field::binary-size(sz), ".eq:", rest::binary>> ->
        [{:int_field, field}, {:range, :eq} | accept(rest, :int)]
      <<^field::binary-size(sz), ".lt:", rest::binary>> ->
        [{:int_field, field}, {:range, :lt} | accept(rest, :int)]
      <<^field::binary-size(sz), ".lte:", rest::binary>> ->
        [{:int_field, field}, {:range, :lte}. accept(rest, :int)]
      <<^field::binary-size(sz), ".gt:", rest::binary>> ->
        [{:int_field, field}, {:range, :gt} | accept(rest, :int)]
      <<^field::binary-size(sz), ".gte:", rest::binary>> ->
        [{:int_field, field}, {:range, :gte} | accept(rest, :int)]
      _ ->
        accept(r_fields, opts, input, :int_field)
    end
  end
  defp accept([], %{float_fields: fields} = opts, input, :int_field), do: accept(fields, opts, input, :float_field)

  #
  # Float fields
  #

  defp accept([field | r_fields], opts, input, :float_field) do
    sz = field |> byte_size

    case input do
      <<^field::binary-size(sz), ":", rest::binary>> ->
        [{:float_field, field}, {:range, :eq} | accept(rest, :float)]
      <<^field::binary-size(sz), ".eq:", rest::binary>> ->
        [{:float_field, field}, {:range, :eq} | accept(rest, :float)]
      <<^field::binary-size(sz), ".lt:", rest::binary>> ->
        [{:float_field, field}, {:range, :lt} | accept(rest, :float)]
      <<^field::binary-size(sz), ".lte:", rest::binary>> ->
        [{:float_field, field}, {:range, :lte} | accept(rest, :float)]
      <<^field::binary-size(sz), ".gt:", rest::binary>> ->
        [{:float_field, field}, {:range, :gt} | accept(rest, :float)]
      <<^field::binary-size(sz), ".gte:", rest::binary>> ->
        [{:float_field, field}, {:range, :gte} | accept(rest, :float)]
      _ ->
        accept(r_fields, opts, input, :float_field)
    end
  end
  defp accept([], %{date_fields: fields} = opts, input, :float_field), do: accept(fields, opts, input, :date_field)

  #
  # Date fields
  #

  defp accept([field | r_fields], opts, input, :date_field) do
    sz = field |> byte_size

    case input do
      <<^field::binary-size(sz), ":", rest::binary>> ->
        [{:date_field, field}, {:range, :eq} | accept(rest, :date)]
      <<^field::binary-size(sz), ".eq:", rest::binary>> ->
        [{:date_field, field}, {:range, :eq} | accept(rest, :date)]
      <<^field::binary-size(sz), ".lt:", rest::binary>> ->
        [{:date_field, field}, {:range, :lt} | accept(rest, :date)]
      <<^field::binary-size(sz), ".lte:", rest::binary>> ->
        [{:date_field, field}, {:range, :lte} | accept(rest, :date)]
      <<^field::binary-size(sz), ".gt:", rest::binary>> ->
        [{:date_field, field}, {:range, :gt} | accept(rest, :date)]
      <<^field::binary-size(sz), ".gte:", rest::binary>> ->
        [{:date_field, field}, {:range, :gte} | accept(rest, :date)]
      _ ->
        accept(r_fields, opts, input, :date_field)
    end
  end

  #
  # Default field handling
  #

  defp accept([], %{default_field: field} = opts, input, :date_field) do
    [{:literal_field, field} | accept(input, :literal)]
  end

  #
  # Text and wildcarded text
  #

  defp accept(input, :literal), do: accept(input, "", :literal)

  defp accept(<<"\\", c::utf8, rest::binary>>, term, :literal), do: accept(rest, term <> <<c::utf8>>, :literal)
  defp accept(<<c::utf8, rest::binary>>, term, :literal) when c in '*?', do: accept(rest, term <> <<c::utf8>>, :wildcard)
  defp accept(<<c::utf8, rest::binary>>, term, :literal), do: accept(rest, term <> <<c::utf8>>, :literal)
  defp accept(<<>>, term, :literal), do: [literal: term]

  defp accept(<<"\\", c::utf8, rest::binary>>, term, :wildcard) when c in '*?', do: accept(rest, term <> <<"\\", c::utf8>>, :wildcard)
  defp accept(<<"\\", c::utf8, rest::binary>>, term, :wildcard), do: accept(rest, term <> <<c::utf8>>, :wildcard)
  defp accept(<<c::utf8, rest::binary>>, term, :wildcard), do: accept(rest, term <> <<c::utf8>>, :wildcard)
  defp accept(<<>>, term, :wildcard), do: [wildcard: term]

  #
  # Booleans
  #

  defp accept("true", :boolean), do: [boolean: true]
  defp accept("false", :boolean), do: [boolean: false]
  defp accept(input, :boolean), do: raise ArgumentError, "Expected a boolean, got `\#{input}'."

  #
  # Floats (integers are also considered valid)
  #

  defp accept(<<"+", rest::binary>>, :float), do: accept(rest, "", :float_w)
  defp accept(<<"-", rest::binary>>, :float), do: accept(rest, "-", :float_w)
  defp accept(input, :float), do: accept(input, "", :float_w)

  defp accept(<<c::utf8, rest::binary>>, term, :float_w) when c in ?0..?9, do: accept(rest, term <> <<c::utf8>>, :float_w)
  defp accept(<<".", rest::binary>>, term, :float_w), do: accept(rest, term <> ".", :float_f)
  defp accept(<<c::utf8, rest::binary>>, term, :float_w), do: raise ArgumentError, "Expected a float, got `\#{<<term::binary, c::utf8, rest::binary>>}'."
  defp accept(<<>>, term, :float_w), do: [float: to_number(term)]

  defp accept(<<c::utf8, rest::binary>>, term, :float_f) when c in ?0..?9, do: accept(rest, term <> <<c::utf8>>, :float_f)
  defp accept(<<c::utf8, rest::binary>>, term, :float_f), do: raise ArgumentError, "Expected a float, got `\#{<<term::binary, c::utf8, rest::binary>>}'."
  defp accept(<<>>, term, :float_f), do: [float: to_number(term)]

  #
  # Integers
  #

  defp accept(<<"+", rest::binary>>, :int), do: accept(rest, "", :int_w)
  defp accept(<<"-", rest::binary>>, :int), do: accept(rest, "-", :int_w)
  defp accept(input, :int), do: accept(input, "", :int_w)

  defp accept(<<c::utf8, rest::binary>>, term, :int_w) when c in ?0..?9, do: accept(rest, term <> <<c::utf8>>, :int_w)
  defp accept(<<c::utf8, rest::binary>>, term, :int_w), do: raise ArgumentError, "Expected an integer, got `\#{<<term::binary, c::utf8, rest::binary>>}'."
  defp accept(<<>>, term, :int_w), do: [int: to_number(term)]

  #
  # IP addresses
  #

  defp accept(<<c1::utf8, c2::utf8, c3::utf8, ".", rest::binary>>, :ip) when c1 in ?0..9 and c2 in ?0..?9 and c3 in ?0..?9, do: accept({})
  defp accept(<<"::ffff:", c1::utf8, c2::utf8, c3::utf8, ".", rest::binary>>, :ip) when c1 in ?0..9 and c2 in ?0..?9 and c3 in ?0..?9, do: accept({})
  defp accept(<<c1::utf8, c2::utf8, ".", rest::binary>>, :ip) when c1 in ?0..9 and c2 in ?0..?9, do: accept({})
  defp accept(<<"::ffff:",c1::utf8, c2::utf8, ".", rest::binary>>, :ip) when c1 in ?0..9 and c2 in ?0..?9, do: accept({})
  defp accept(<<c1::utf8, ".", rest::binary>>, :ip) when c1 in ?0..9, do: accept({})
  defp accept(<<"::ffff:", c1::utf8, ".", rest::binary>>, :ip) when c1 in ?0..9, do: accept({})

  defp to_number(term) do
    {float_val, _} = :string.to_float(term)
    {int_val, _} = :string.to_integer(term)

    cond do
      is_float(float_val) ->
        float_val
      is_integer(int_val) ->
        int_val
      true ->
        raise ArgumentError, "Expected a number."
    end
  end
end
"""