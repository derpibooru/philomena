defmodule PhilomenaWeb.LayoutView do
  use PhilomenaWeb, :view

  import PhilomenaWeb.Config
  alias PhilomenaWeb.ImageView
  alias Philomena.Config
  alias Philomena.Users.User
  alias Plug.Conn
  alias Philomena.Games

  @themes User.themes()

  def layout_class(conn) do
    conn.assigns[:layout_class] || "layout--narrow"
  end

  def container_class(%{use_centered_layout: false}), do: nil
  def container_class(_user), do: "layout--center-aligned"

  def philomena_version, do: Application.spec(:philomena, :vsn)

  def render_time(conn) do
    (Time.diff(Time.utc_now(), conn.assigns[:start_time], :microsecond) / 1000.0)
    |> Float.round(3)
    |> Float.to_string()
  end

  def hide_version do
    Application.get_env(:philomena, :hide_version) == "true"
  end

  def cdn_host do
    Application.get_env(:philomena, :cdn_host)
  end

  def vite_reload? do
    Application.get_env(:philomena, :vite_reload)
  end

  def generator_name do
    if hide_version() do
      "Philomena"
    else
      "Philomena v#{philomena_version()}"
    end
  end

  defp ignored_tag_list(nil), do: []
  defp ignored_tag_list([]), do: []
  defp ignored_tag_list([{tag, _body, _dnp_entries}]), do: [tag.id]
  defp ignored_tag_list(tags), do: Enum.map(tags, & &1.id)

  def clientside_data(conn) do
    conn = Conn.fetch_cookies(conn)

    extra = Map.get(conn.assigns, :clientside_data, [])
    interactions = Map.get(conn.assigns, :interactions, [])
    user = conn.assigns.current_user
    filter = conn.assigns.current_filter

    data = [
      filter_id: filter.id,
      hidden_tag_list: JSON.encode!(filter.hidden_tag_ids),
      hidden_filter: PhilomenaQuery.Parse.String.normalize(filter.hidden_complex_str || ""),
      spoilered_tag_list: JSON.encode!(filter.spoilered_tag_ids),
      spoilered_filter: PhilomenaQuery.Parse.String.normalize(filter.spoilered_complex_str || ""),
      user_id: if(user, do: user.id, else: nil),
      user_name: if(user, do: user.name, else: nil),
      user_slug: if(user, do: user.slug, else: nil),
      user_is_signed_in: if(user, do: "true", else: "false"),
      user_can_edit_filter: if(user, do: filter.user_id == user.id, else: "false") |> to_string(),
      spoiler_type: if(user, do: user.spoiler_type, else: "static"),
      watched_tag_list: JSON.encode!(if(user, do: user.watched_tag_ids, else: [])),
      fancy_tag_edit: if(user, do: user.fancy_tag_field_on_edit, else: "true") |> to_string(),
      fancy_tag_upload: if(user, do: user.fancy_tag_field_on_upload, else: "true") |> to_string(),
      interactions: JSON.encode!(interactions),
      ignored_tag_list: JSON.encode!(ignored_tag_list(conn.assigns[:tags])),
      hide_staff_tools: conn.cookies["hide_staff_tools"] |> to_string()
    ]

    data = Keyword.merge(data, extra)

    content_tag(:div, "", class: "js-datastore", data: data)
  end

  def footer_data do
    Config.get(:footer)
  end

  def stylesheet_path(conn, %{theme: theme})
      when theme in @themes,
      do: static_path(conn, "/css/#{theme}.css")

  def stylesheet_path(_conn, _user),
    do: ~p"/css/dark-blue.css"

  def light_stylesheet_path(_conn),
    do: ~p"/css/light-blue.css"

  def theme_name(%{theme: theme}), do: theme
  def theme_name(_user), do: "dark-blue"

  def artist_tags(tags),
    do: Enum.filter(tags, &(&1.namespace == "artist"))

  def opengraph?(conn),
    do:
      !is_nil(conn.assigns[:image]) and conn.assigns.image.__meta__.state == :loaded and
        is_list(conn.assigns.image.tags)

  def hides_images?(conn),
    do: can?(conn, :hide, %Philomena.Images.Image{})

  def manages_site_notices?(conn),
    do: can?(conn, :index, Philomena.SiteNotices.SiteNotice)

  def manages_tags?(conn),
    do: can?(conn, :edit, %Philomena.Tags.Tag{})

  def manages_users?(conn),
    do: can?(conn, :index, Philomena.Users.User)

  def manages_forums?(conn),
    do: can?(conn, :edit, Philomena.Forums.Forum)

  def manages_ads?(conn),
    do: can?(conn, :index, Philomena.Adverts.Advert)

  def manages_badges?(conn),
    do: can?(conn, :index, Philomena.Badges.Badge)

  def manages_static_pages?(conn),
    do: can?(conn, :edit, %Philomena.StaticPages.StaticPage{})

  def manages_mod_notes?(conn),
    do: can?(conn, :index, Philomena.ModNotes.ModNote)

  def manages_bans?(conn),
    do: can?(conn, :create, Philomena.Bans.User)

  def can_see_moderation_log?(conn),
    do: can?(conn, :index, Philomena.ModerationLogs.ModerationLog)

  def viewport_meta_tag(conn) do
    ua = get_user_agent(conn)

    if String.contains?(ua, ["Mobile", "webOS"]) do
      tag(:meta, name: "viewport", content: "width=device-width, initial-scale=1")
    else
      tag(:meta, name: "viewport", content: "width=1024, initial-scale=1")
    end
  end

  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [ua] -> ua
      _ -> ""
    end
  end

  def current_scores do
    team_scores = Games.team_scores()
    diff = Enum.at(team_scores, 0) - Enum.at(team_scores, 1)
    # guarantee that we're not dividing by zero lol
    total = Enum.sum(team_scores) + 0.001

    %{
      team1_score: Enum.at(team_scores, 0),
      team2_score: Enum.at(team_scores, 1),
      total_score: total,
      diff: diff,
      percentage: "#{50 + 50 * (diff / total * -1)}"
    }
  end
end
