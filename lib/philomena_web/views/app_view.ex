defmodule PhilomenaWeb.AppView do
  use PhilomenaWeb, :view

  @time_strings %{
    seconds: "less than a minute",
    minute: "about a minute",
    minutes: "%d minutes",
    hour: "about an hour",
    hours: "about %d hours",
    day: "a day",
    days: "%d days",
    month: "about a month",
    months: "%d months",
    year: "about a year",
    years: "%d years"
  }

  def pretty_time(time) do
    seconds = NaiveDateTime.diff(NaiveDateTime.utc_now(), time, :second)
    relation = if seconds < 0, do: "from now", else: "ago"

    seconds = abs(seconds)
    minutes = abs(div(seconds, 60))
    hours = abs(div(minutes, 60))
    days = abs(div(hours, 24))
    months = abs(div(days, 30))
    years = abs(div(days, 365))

    words =
      cond do
        seconds < 45 -> String.replace(@time_strings[:seconds], "%d", to_string(seconds))
        seconds < 90 -> String.replace(@time_strings[:minute], "%d", to_string(1))
        minutes < 45 -> String.replace(@time_strings[:minutes], "%d", to_string(minutes))
        minutes < 90 -> String.replace(@time_strings[:hour], "%d", to_string(1))
        hours < 24 -> String.replace(@time_strings[:hours], "%d", to_string(hours))
        hours < 42 -> String.replace(@time_strings[:day], "%d", to_string(1))
        days < 30 -> String.replace(@time_strings[:days], "%d", to_string(days))
        days < 45 -> String.replace(@time_strings[:month], "%d", to_string(1))
        days < 365 -> String.replace(@time_strings[:months], "%d", to_string(months))
        days < 548 -> String.replace(@time_strings[:year], "%d", to_string(1))
        true -> String.replace(@time_strings[:years], "%d", to_string(years))
      end

    content_tag(:time, "#{words} #{relation}", datetime: time |> NaiveDateTime.to_iso8601())
  end
end
