defmodule PhilomenaWeb.ProfileView do
  use PhilomenaWeb, :view

  def award_order(awards) do
    Enum.sort_by(awards, &{&1.badge.priority, DateTime.to_unix(&1.awarded_on)}, &>=/2)
  end

  def badge_image(badge, options \\ []) do
    img_tag(badge_url_root() <> "/" <> badge.image, options)
  end

  def current?(%{id: id}, %{id: id}), do: true
  def current?(_user1, _user2), do: false

  def manages_awards?(conn),
    do: can?(conn, :create, Philomena.Badges.Award)

  def manages_links?(conn, user),
    do: can?(conn, :edit_links, user)

  def should_see_link?(conn, user, link),
    do: link.public or can?(conn, :edit, link) or current?(user, conn.assigns.current_user)

  def link_block_class(%{public: false}), do: "block__content--destroyed"
  def link_block_class(_link), do: nil

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

    content_tag :svg, width: "100%", preserveAspectRatio: "none", viewBox: "0 0 90 20" do
      for {val, i} <- Enum.with_index(data) do
        # Filter out negative values
        calc = max(val, 0)

        # Lerp or 0 if not present
        height = zero_div((calc - min) * 20, max - min)

        # In SVG coords, y grows down
        y = 20 - height

        content_tag :rect, class: "barline__bar", x: i, y: y, width: 1, height: height do
          content_tag(:title, val)
        end
      end
    end
  end

  def tag_disjunction(tags) do
    tags
    |> Enum.map(& &1.name)
    |> Enum.uniq()
    |> Enum.join(" || ")
  end

  def can_ban?(conn),
    do: can?(conn, :index, Philomena.Bans.User)

  def can_index_user?(conn),
    do: can?(conn, :index, Philomena.Users.User)

  def can_read_mod_notes?(conn),
    do: can?(conn, :index, Philomena.ModNotes.ModNote)

  def enabled_text(true), do: "Enabled"
  def enabled_text(_else), do: "Disabled"

  def user_abbrv(conn, %{name: name} = user) do
    abbrv =
      String.upcase(initials_abbrv(name) || uppercase_abbrv(name) || first_letters_abbrv(name))

    abbrv = "(" <> abbrv <> ")"

    link(abbrv, to: Routes.profile_path(conn, :show, user))
  end

  def user_abbrv(_conn, _user), do: content_tag(:span, "(n/a)")

  defp initials_abbrv(name) do
    case String.split(name, " ", parts: 4) do
      [
        <<a1::utf8, _r1::binary>>,
        <<a2::utf8, _r2::binary>>,
        <<a3::utf8, _r3::binary>>,
        <<a4::utf8, _r4::binary>>
      ] ->
        <<a1::utf8, a2::utf8, a3::utf8, a4::utf8>>

      [<<a1::utf8, _r1::binary>>, <<a2::utf8, _r2::binary>>, <<a3::utf8, _r3::binary>>] ->
        <<a1::utf8, a2::utf8, a3::utf8>>

      [<<a1::utf8, _r1::binary>>, <<a2::utf8, _r2::binary>>] ->
        <<a1::utf8, a2::utf8>>

      _ ->
        nil
    end
  end

  defp uppercase_abbrv(name) do
    case Regex.scan(~r/([A-Z])/, name, capture: :all_but_first) do
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
