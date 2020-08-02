defmodule PhilomenaWeb.LayoutView do
  use PhilomenaWeb, :view

  alias PhilomenaWeb.ImageView
  alias Philomena.Servers.Config
  alias Plug.Conn

  def layout_class(conn) do
    conn.assigns[:layout_class] || "layout--narrow"
  end

  def container_class(%{use_centered_layout: true}), do: "layout--center-aligned"
  def container_class(_user), do: nil

  def render_time(conn) do
    (Time.diff(Time.utc_now(), conn.assigns[:start_time], :microsecond) / 1000.0)
    |> Float.round(3)
    |> Float.to_string()
  end

  def hostname() do
    {:ok, host} = :inet.gethostname()

    host |> to_string
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
      hidden_tag_list: Jason.encode!(filter.hidden_tag_ids),
      hidden_filter: Philomena.Search.String.normalize(filter.hidden_complex_str || ""),
      spoilered_tag_list: Jason.encode!(filter.spoilered_tag_ids),
      spoilered_filter: Philomena.Search.String.normalize(filter.spoilered_complex_str || ""),
      user_id: if(user, do: user.id, else: nil),
      user_name: if(user, do: user.name, else: nil),
      user_slug: if(user, do: user.slug, else: nil),
      user_is_signed_in: !!user,
      user_can_edit_filter: if(user, do: filter.user_id == user.id, else: false),
      spoiler_type: if(user, do: user.spoiler_type, else: "static"),
      watched_tag_list: Jason.encode!(if(user, do: user.watched_tag_ids, else: [])),
      fancy_tag_edit: if(user, do: user.fancy_tag_field_on_edit, else: true),
      fancy_tag_upload: if(user, do: user.fancy_tag_field_on_upload, else: true),
      interactions: Jason.encode!(interactions),
      ignored_tag_list: Jason.encode!(ignored_tag_list(conn.assigns[:tags])),
      hide_staff_tools: conn.cookies["hide_staff_tools"]
    ]

    data = Keyword.merge(data, extra)

    content_tag(:div, "", class: "js-datastore", data: data)
  end

  def footer_data do
    Config.get(:footer)
  end

  def stylesheet_path(conn, %{theme: "dark"}),
    do: Routes.static_path(conn, "/css/dark.css")

  def stylesheet_path(conn, %{theme: "light"}),
    do: Routes.static_path(conn, "/css/light.css")

  def stylesheet_path(conn, %{theme: "green"}),
    do: Routes.static_path(conn, "/css/green.css")

  def stylesheet_path(conn, %{theme: "orange"}),
    do: Routes.static_path(conn, "/css/orange.css")

  def stylesheet_path(conn, %{theme: "fuchsia"}),
    do: Routes.static_path(conn, "/css/fuchsia.css")

  def stylesheet_path(conn, _user),
    do: Routes.static_path(conn, "/css/default.css")

  def theme_name(%{theme: theme}), do: theme
  def theme_name(_user), do: "default"

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

  def viewport_meta_tag(conn) do
    ua = get_user_agent(conn)

    case String.contains?(ua, ["Mobile", "webOS"]) do
      true -> tag(:meta, name: "viewport", content: "width=device-width, initial-scale=1")
      _false -> tag(:meta, name: "viewport", content: "width=1024, initial-scale=1")
    end
  end

  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [ua] -> ua
      _ -> ""
    end
  end
end
