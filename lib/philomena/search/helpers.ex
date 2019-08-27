defmodule Philomena.Search.Helpers do
  import NimbleParsec

  def to_number(term) do
    {float_val, _} = :string.to_float(term)
    {int_val, _} = :string.to_integer(term)

    cond do
      is_float(float_val) ->
        float_val

      is_integer(int_val) ->
        int_val
    end
  end

  defp build_datetime(naive, tz_off, tz_hour, tz_minute) do
    # Unbelievable that there is no way to build this with integer arguments.

    tz_hour =
      tz_hour
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    tz_minute =
      tz_minute
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    iso8601_string = "#{NaiveDateTime.to_iso8601(naive)}#{tz_off}#{tz_hour}#{tz_minute}"

    {:ok, datetime, _offset} = DateTime.from_iso8601(iso8601_string)

    datetime
  end

  defp timezone_bounds([]), do: ["+", 0, 0]
  defp timezone_bounds([tz_off, tz_hour]), do: [tz_off, tz_hour, 0]
  defp timezone_bounds([tz_off, tz_hour, tz_minute]), do: [tz_off, tz_hour, tz_minute]

  defp date_bounds([year]) do
    lower = %NaiveDateTime{year: year, month: 1, day: 1, hour: 0, minute: 0, second: 0}
    upper = NaiveDateTime.add(lower, 31_536_000, :second)
    [lower, upper]
  end

  defp date_bounds([year, month]) do
    lower = %NaiveDateTime{year: year, month: month, day: 1, hour: 0, minute: 0, second: 0}
    upper = NaiveDateTime.add(lower, 2_592_000, :second)
    [lower, upper]
  end

  defp date_bounds([year, month, day]) do
    lower = %NaiveDateTime{year: year, month: month, day: day, hour: 0, minute: 0, second: 0}
    upper = NaiveDateTime.add(lower, 86400, :second)
    [lower, upper]
  end

  defp date_bounds([year, month, day, hour]) do
    lower = %NaiveDateTime{year: year, month: month, day: day, hour: hour, minute: 0, second: 0}
    upper = NaiveDateTime.add(lower, 3600, :second)
    [lower, upper]
  end

  defp date_bounds([year, month, day, hour, minute]) do
    lower = %NaiveDateTime{
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: 0
    }

    upper = NaiveDateTime.add(lower, 60, :second)
    [lower, upper]
  end

  defp date_bounds([year, month, day, hour, minute, second]) do
    lower = %NaiveDateTime{
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second
    }

    upper = NaiveDateTime.add(lower, 1, :second)
    [lower, upper]
  end

  def absolute_datetime(opts) do
    date = Keyword.fetch!(opts, :date)
    timezone = Keyword.get(opts, :timezone, [])

    [lower, upper] = date_bounds(date)
    [tz_off, tz_hour, tz_minute] = timezone_bounds(timezone)

    lower = build_datetime(lower, tz_off, tz_hour, tz_minute)
    upper = build_datetime(upper, tz_off, tz_hour, tz_minute)

    [lower, upper]
  end

  def relative_datetime([count, scale]) do
    now = NaiveDateTime.utc_now()

    lower = NaiveDateTime.add(now, count * -scale, :second)
    upper = NaiveDateTime.add(now, (count - 1) * -scale, :second)

    [lower, upper]
  end

  def full_choice(combinator \\ empty(), choices)

  def full_choice(combinator, []) do
    combinator |> eos() |> string("<eos>")
  end

  def full_choice(combinator, [choice]) do
    combinator |> concat(choice)
  end

  def full_choice(combinator, choices) do
    choice(combinator, choices)
  end

  def contains_wildcard?(value) do
    String.match?(value, ~r/(?<!\\)(?:\\\\)*[\*\?]/)
  end

  def unescape_wildcard(value) do
    # '*' and '?' are wildcard characters in the right context;
    # don't unescape them.
    Regex.replace(~r/(?<!\\)(?:\\)*([^\\\*\?])/, value, "\\1")
  end

  def unescape_regular(value) do
    Regex.replace(~r/(?<!\\)(?:\\)*(.)/, value, "\\1")
  end

  def process_term(term) do
    term |> String.trim() |> String.downcase()
  end
end
