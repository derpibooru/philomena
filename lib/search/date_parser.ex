defmodule Search.DateParser do
  import NimbleParsec

  defp to_int(input), do: Search.Helpers.to_int(input)

  defp build_datetime(naive, tz_off, tz_hour, tz_minute) do
    tz_hour =
      tz_hour
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    tz_minute =
      tz_minute
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    iso8601_string = "#{NaiveDateTime.to_iso8601(naive)}#{tz_off}#{tz_hour}#{tz_minute}"

    # Unbelievable that there is no way to build this with integer arguments.
    # WTF, Elixir?
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

  defp absolute_datetime(opts) do
    date = Keyword.fetch!(opts, :date)
    timezone = Keyword.get(opts, :timezone, [])

    [lower, upper] = date_bounds(date)
    [tz_off, tz_hour, tz_minute] = timezone_bounds(timezone)

    lower = build_datetime(lower, tz_off, tz_hour, tz_minute)
    upper = build_datetime(upper, tz_off, tz_hour, tz_minute)

    [lower, upper]
  end

  defp relative_datetime([count, scale]) do
    now = DateTime.utc_now()

    lower = DateTime.add(now, (count + 1) * -scale, :second)
    upper = DateTime.add(now, count * -scale, :second)

    [lower, upper]
  end

  space =
    choice([string(" "), string("\t"), string("\n"), string("\r"), string("\v"), string("\f")])
    |> ignore()

  pos_2dig_int =
    ascii_char('0123456789')
    |> ascii_char('123456789')
    |> reduce(:to_int)

  year = integer(4)
  month = pos_2dig_int
  day = pos_2dig_int

  hour = integer(2)
  minute = integer(2)
  second = integer(2)
  tz_hour = integer(2)
  tz_minute = integer(2)

  ymd_sep = ignore(string("-"))
  hms_sep = ignore(string(":"))
  iso8601_sep = ignore(choice([string("T"), string("t"), space]))
  iso8601_tzsep = choice([string("+"), string("-")])
  zulu = ignore(choice([string("Z"), string("z")]))

  date_part =
    year
    |> optional(
      ymd_sep
      |> concat(month)
      |> optional(
        ymd_sep
        |> concat(day)
        |> optional(
          iso8601_sep
          |> optional(
            hour
            |> optional(
              hms_sep
              |> concat(minute)
              |> optional(concat(hms_sep, second))
            )
          )
        )
      )
    )
    |> tag(:date)

  timezone_part =
    choice([
      iso8601_tzsep
      |> concat(tz_hour)
      |> optional(
        hms_sep
        |> concat(tz_minute)
      )
      |> tag(:timezone),
      zulu
    ])

  absolute_date =
    date_part
    |> optional(timezone_part)
    |> reduce(:absolute_datetime)
    |> unwrap_and_tag(:date)

  relative_date =
    integer(min: 1)
    |> ignore(concat(space, empty()))
    |> choice([
      string("second") |> optional(string("s")) |> replace(1),
      string("minute") |> optional(string("s")) |> replace(60),
      string("hour") |> optional(string("s")) |> replace(3_600),
      string("day") |> optional(string("s")) |> replace(86_400),
      string("week") |> optional(string("s")) |> replace(604_800),
      string("month") |> optional(string("s")) |> replace(2_592_000),
      string("year") |> optional(string("s")) |> replace(31_536_000)
    ])
    |> ignore(string(" ago"))
    |> reduce(:relative_datetime)
    |> unwrap_and_tag(:date)

  date =
    choice([
      absolute_date,
      relative_date
    ])
    |> repeat(space)
    |> eos()
    |> label("a RFC3339 datetime fragment, like `2019-01-01', or relative date, like `3 days ago'")

  defparsec :parse, date
end
