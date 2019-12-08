defmodule PhilomenaWeb.AppView do
  alias PhilomenaWeb.Router.Helpers, as: Routes
  use Phoenix.HTML

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

  @months %{
    1 => "January",
    2 => "February",
    3 => "March",
    4 => "April",
    5 => "May",
    6 => "June",
    7 => "July",
    8 => "August",
    9 => "September",
    10 => "October",
    11 => "November",
    12 => "December"
  }

  def pretty_time(time) do
    seconds = NaiveDateTime.diff(NaiveDateTime.utc_now(), time, :second)
    relation = if seconds < 0, do: "from now", else: "ago"
    time = time |> DateTime.from_naive!("Etc/UTC")

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

    content_tag(:time, "#{words} #{relation}", datetime: DateTime.to_iso8601(time), title: datetime_string(time))
  end

  def can?(conn, action, model) do
    Canada.Can.can?(conn.assigns.current_user, action, model)
  end

  def map_join(enumerable, joiner, map_fn) do
    enumerable
    |> Enum.map(map_fn)
    |> Enum.intersperse(joiner)
  end

  def number_with_delimiter(nil), do: "0"
  def number_with_delimiter(number) do
    number
    |> to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse(&1))
    |> Enum.reverse()
    |> Enum.join(",")
  end

  def pluralize(singular, plural, count) do
    if count == 1 do
      singular
    else
      plural
    end
  end

  def button_to(text, route, args \\ []) do
    method = Keyword.get(args, :method, "get")
    class = Keyword.get(args, :class, nil)
    data = Keyword.get(args, :data, [])

    form_for(nil, route, [method: method, class: "button_to"], fn _f ->
      submit text, class: class, data: data
    end)
  end

  def escape_nl2br(text) do
    text
    |> String.split("\n")
    |> Enum.map(&html_escape/1)
    |> Enum.map(&safe_to_string/1)
    |> Enum.join("<br/>")
    |> raw()
  end

  defp datetime_string(time) do
    :io_lib.format("~2..0B:~2..0B:~2..0B, ~s ~B, ~B", [
      time.hour,
      time.minute,
      time.second,
      @months[time.month],
      time.day,
      time.year
    ])
    |> to_string()
  end

  defp text_or_na(nil), do: "N/A"
  defp text_or_na(text), do: text

  def link_to_ip(conn, ip) do
    link(text_or_na(ip), to: Routes.ip_profile_path(conn, :show, to_string(ip)))
  end

  def link_to_fingerprint(conn, fp) do
    link(String.slice(text_or_na(fp), 0..6), to: Routes.fingerprint_profile_path(conn, :show, fp))
  end

  def blank?(nil), do: true
  def blank?(""), do: true
  def blank?([]), do: true
  def blank?(map) when is_map(map), do: map == %{}
  def blank?(str) when is_binary(str), do: String.trim(str) == ""
  def blank?(_object), do: false

  def present?(object), do: not blank?(object)
end
