defmodule PhilomenaQuery.RelativeDate do
  @moduledoc """
  Relative date parsing, for strings like "a week ago" or "5 years from now".
  """

  import NimbleParsec

  number_words =
    choice([
      string("a") |> replace(1),
      string("an") |> replace(1),
      string("one") |> replace(1),
      string("two") |> replace(2),
      string("three") |> replace(3),
      string("four") |> replace(4),
      string("five") |> replace(5),
      string("six") |> replace(6),
      string("seven") |> replace(7),
      string("eight") |> replace(8),
      string("nine") |> replace(9),
      string("ten") |> replace(10),
      integer(min: 1)
    ])

  time_specifier =
    choice([
      string("second") |> replace(1),
      string("minute") |> replace(60),
      string("hour") |> replace(3_600),
      string("day") |> replace(86_400),
      string("week") |> replace(604_800),
      string("month") |> replace(2_592_000),
      string("year") |> replace(31_536_000)
    ])
    |> ignore(optional(string("s")))

  direction_specifier =
    choice([
      string("ago") |> replace(-1),
      string("from now") |> replace(1)
    ])

  space = ignore(repeat(string(" ")))

  permanent_specifier =
    choice([
      string("moon"),
      string("forever"),
      string("permanent"),
      string("permanently"),
      string("indefinite"),
      string("indefinitely")
    ])

  permanent =
    space
    |> concat(permanent_specifier)
    |> concat(space)
    |> eos()
    |> unwrap_and_tag(:permanent)

  now =
    space
    |> string("now")
    |> concat(space)
    |> eos()
    |> unwrap_and_tag(:now)

  date =
    space
    |> concat(number_words)
    |> concat(space)
    |> concat(time_specifier)
    |> concat(space)
    |> concat(direction_specifier)
    |> concat(space)
    |> eos()
    |> tag(:relative_date)

  relative_date =
    choice([
      permanent,
      now,
      date
    ])

  defparsecp(:relative_date, relative_date)

  @doc """
  Parse an absolute date in valid ISO 8601 format, or an English-language relative date.

  See `parse_absolute/1` and `parse_relative/1` for examples of what may be accepted
  by this function.
  """
  @spec parse_absolute(String.t()) :: {:ok, DateTime.t()} | {:error, any()}
  def parse(input) do
    input =
      input
      |> to_string()
      |> String.trim()

    case parse_absolute(input) do
      {:ok, datetime} ->
        {:ok, datetime}

      _error ->
        parse_relative(String.downcase(input))
    end
  end

  @doc """
  Parse an absolute date, given in a valid ISO 8601 format.

  ## Example

      iex> PhilomenaQuery.RelativeDate.parse_absolute("2024-01-01T00:00:00Z")
      {:ok, ~U[2024-01-01 00:00:00Z]}

      iex> PhilomenaQuery.RelativeDate.parse_absolute("2024-01-01T00:00:00-01:00")
      {:ok, ~U[2024-01-01 01:00:00Z]

      iex> PhilomenaQuery.RelativeDate.parse_absolute("2024")
      {:error, "Parse error"}

  """
  @spec parse_absolute(String.t()) :: {:ok, DateTime.t()} | {:error, any()}
  def parse_absolute(input) do
    case DateTime.from_iso8601(input) do
      {:ok, datetime, _offset} ->
        {:ok, DateTime.truncate(datetime, :second)}

      _error ->
        {:error, "Parse error"}
    end
  end

  @doc """
  Parse an English-language relative date. Accepts "moon" to mean 1000 years from now.

  ## Example

      iex> PhilomenaQuery.RelativeDate.parse_relative("a year ago")
      {:ok, ~U[2023-01-01 00:00:00Z]

      iex> PhilomenaQuery.RelativeDate.parse_relative("three days from now")
      {:ok, ~U[2024-01-04 00:00:00Z]}

      iex> PhilomenaQuery.RelativeDate.parse_relative("moon")
      {:ok, ~U[3024-01-01 00:00:00Z]}

      iex> PhilomenaQuery.RelativeDate.parse_relative("2024")
      {:error, "Parse error"}

  """
  @spec parse_relative(String.t()) :: {:ok, DateTime.t()} | {:error, any()}
  def parse_relative(input) do
    now = DateTime.utc_now(:second)

    case relative_date(input) do
      {:ok, [permanent: _permanent], _1, _2, _3, _4} ->
        {:ok, DateTime.add(now, 31_536_000_000, :second)}

      {:ok, [now: _now], _1, _2, _3, _4} ->
        {:ok, now}

      {:ok, [relative_date: [amount, scale, direction]], _1, _2, _3, _4} ->
        {:ok, DateTime.add(now, amount * scale * direction, :second)}

      _error ->
        {:error, "Parse error"}
    end
  end
end
