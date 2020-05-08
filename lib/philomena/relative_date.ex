defmodule Philomena.RelativeDate do
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

  moon =
    space
    |> string("moon")
    |> concat(space)
    |> eos()
    |> unwrap_and_tag(:moon)

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
      moon,
      now,
      date
    ])

  defparsecp(:relative_date, relative_date)

  def parse(input) do
    input =
      input
      |> to_string()
      |> String.trim()

    case parse_absolute(input) do
      {:ok, datetime} ->
        {:ok, datetime}

      _error ->
        parse_relative(input)
    end
  end

  def parse_absolute(input) do
    case DateTime.from_iso8601(input) do
      {:ok, datetime, _offset} ->
        {:ok, datetime |> DateTime.truncate(:second)}

      _error ->
        {:error, "Parse error"}
    end
  end

  def parse_relative(input) do
    case relative_date(input) do
      {:ok, [moon: _moon], _1, _2, _3, _4} ->
        {:ok,
         DateTime.utc_now() |> DateTime.add(31_536_000_000, :second) |> DateTime.truncate(:second)}

      {:ok, [now: _now], _1, _2, _3, _4} ->
        {:ok, DateTime.utc_now() |> DateTime.truncate(:second)}

      {:ok, [relative_date: [amount, scale, direction]], _1, _2, _3, _4} ->
        {:ok,
         DateTime.utc_now()
         |> DateTime.add(amount * scale * direction, :second)
         |> DateTime.truncate(:second)}

      _error ->
        {:error, "Parse error"}
    end
  end
end
