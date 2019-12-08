defmodule PhilomenaWeb.ProfileView do
  use PhilomenaWeb, :view

  def award_order(awards) do
    Enum.sort_by(awards, &{!&1.badge.priority, DateTime.to_unix(&1.awarded_on)})
  end

  def badge_image(badge, options \\ []) do
    img_tag(badge_url_root() <> "/" <> badge.image, options)
  end

  def current?(%{id: id}, %{id: id}), do: true
  def current?(_user1, _user2), do: false

  def award_title(%{badge_name: nil} = award),
    do: award.badge.title
  def award_title(%{badge_name: ""} = award),
    do: award.badge.title
  def award_title(award),
    do: award.badge_name

  def commission_status(%{open: true}), do: "Open"
  def commission_status(_commission), do: "Closed"

  def sparkline_data(data) do
    # Normalize range
    {min, max} = Enum.min_max(data)
    max = max(max, 0)
    min = max(min, 0)

    content_tag :svg, [width: "100%", preserveAspectRatio: "none", viewBox: "0 0 90 20"] do
      for {val, i} <- Enum.with_index(data) do
        # Filter out negative values
        calc = max(val, 0)

        # Lerp or 0 if not present
        height = zero_div((calc - min) * 20, max - min)

        # In SVG coords, y grows down
        y = 20 - height

        content_tag :rect, [class: "barline__bar", x: i, y: y, width: 1, height: height] do
          content_tag :title, val
        end
      end
    end
  end

  def tag_disjunction(tags) do
    Enum.map_join(tags, " || ", & &1.name)
  end

  def user_abbrv(%{name: name}) do
    String.upcase(initials_abbrv(name) || uppercase_abbrv(name) || first_letters_abbrv(name))
  end
  def user_abbrv(_user), do: content_tag(:span, "(n/a)")

  defp initials_abbrv(name) do
    case String.split(name, " ", parts: 4) do
      [<<a1::utf8, _rest::binary>>, <<a2::utf8, _rest::binary>>, <<a3::utf8, _rest::binary>>, <<a4::utf8, _rest::binary>>] ->
        <<a1::utf8, a2::utf8, a3::utf8, a4::utf8>>

      [<<a1::utf8, _rest::binary>>, <<a2::utf8, _rest::binary>>, <<a3::utf8, _rest::binary>>] ->
        <<a1::utf8, a2::utf8, a3::utf8>>

      [<<a1::utf8, _rest::binary>>, <<a2::utf8, _rest::binary>>] ->
        <<a1::utf8, a2::utf8>>

      _ ->
        nil
    end
  end

  defp uppercase_abbrv(name) do
    case Regex.scan(~r/[A-Z]/, name, capture: :all_but_first) do
      [] ->
        nil

      list ->
        Enum.join(list)
    end
  end

  defp first_letters_abbrv(name) do
    String.slice(name, 0, 4)
  end

  defp zero_div(_num, 0), do: 0
  defp zero_div(num, den), do: div(num, den)

  defp badge_url_root do
    Application.get_env(:philomena, :badge_url_root)
  end
end