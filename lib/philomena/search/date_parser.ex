defmodule Philomena.Search.DateParser do
  import NimbleParsec
  @dialyzer [:no_match, :no_unused]

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
    case DateTime.from_iso8601(iso8601_string) do
      {:ok, datetime, _offset} ->
        {:ok, datetime}

      _ ->
        :error
    end
  end

  defp timezone_bounds([]), do: ["+", 0, 0]
  defp timezone_bounds([tz_off, tz_hour]), do: [tz_off, tz_hour, 0]
  defp timezone_bounds([tz_off, tz_hour, tz_minute]), do: [tz_off, tz_hour, tz_minute]

  defp days_in_month(year, month) when month in 1..12 do
    Calendar.ISO.days_in_month(year, month)
  end

  defp days_in_month(_year, _month) do
    0
  end

  defp lower_upper(tuple, offset_amount) do
    case NaiveDateTime.from_erl(tuple) do
      {:ok, lower} ->
        upper = NaiveDateTime.add(lower, offset_amount, :second)
        {:ok, [lower, upper]}

      _ ->
        :error
    end
  end

  defp date_bounds([year]) do
    lower_upper({{year, 1, 1}, {0, 0, 0}}, 31_536_000)
  end

  defp date_bounds([year, month]) do
    days = days_in_month(year, month)
    lower_upper({{year, month, 1}, {0, 0, 0}}, 86_400 * days)
  end

  defp date_bounds([year, month, day]) do
    lower_upper({{year, month, day}, {0, 0, 0}}, 86_400)
  end

  defp date_bounds([year, month, day, hour]) do
    lower_upper({{year, month, day}, {hour, 0, 0}}, 3_600)
  end

  defp date_bounds([year, month, day, hour, minute]) do
    lower_upper({{year, month, day}, {hour, minute, 0}}, 60)
  end

  defp date_bounds([year, month, day, hour, minute, second]) do
    lower_upper({{year, month, day}, {hour, minute, second}}, 1)
  end

  defp absolute_datetime(_rest, opts, context, _line, _offset) do
    date = Keyword.fetch!(opts, :date)
    timezone = Keyword.get(opts, :timezone, [])

    [tz_off, tz_hour, tz_minute] = timezone_bounds(timezone)

    with {:ok, [lower, upper]} <- date_bounds(date),
         {:ok, lower} <- build_datetime(lower, tz_off, tz_hour, tz_minute),
         {:ok, upper} <- build_datetime(upper, tz_off, tz_hour, tz_minute) do
      {[[lower, upper]], context}
    else
      _ ->
        date = Enum.join(date ++ timezone, ", ")
        {:error, "invalid date format in input, parsed as #{date}"}
    end
  end

  defp relative_datetime(_rest, [count, scale], context, _line, _offset) do
    millenium_seconds = 31_536_000_000

    case count * scale <= millenium_seconds do
      true ->
        now = DateTime.utc_now()

        lower = DateTime.add(now, (count + 1) * -scale, :second)
        upper = DateTime.add(now, count * -scale, :second)

        {[[lower, upper]], context}

      _false ->
        {:error,
         "invalid date format in input; requested time #{count * scale} seconds is over a millenium ago"}
    end
  end

  space =
    choice([string(" "), string("\t"), string("\n"), string("\r"), string("\v"), string("\f")])
    |> ignore()

  year = integer(4)
  month = integer(2)
  day = integer(2)

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
    |> eos()
    |> post_traverse(:absolute_datetime)
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
    |> eos()
    |> post_traverse(:relative_datetime)
    |> unwrap_and_tag(:date)

  date =
    choice([
      absolute_date,
      relative_date
    ])
    |> repeat(space)
    |> eos()
    |> label(
      "a RFC3339 datetime fragment, like `2019-01-01', or relative date, like `3 days ago'"
    )

  defparsec(:parse, date)
end
