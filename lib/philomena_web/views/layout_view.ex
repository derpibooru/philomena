defmodule PhilomenaWeb.LayoutView do
  use PhilomenaWeb, :view

  def render_time(conn) do
    (Time.diff(Time.utc_now(), conn.assigns[:start_time], :microsecond) / 1000.0)
    |> Float.round(3)
    |> Float.to_string()
  end

  def hostname() do
    {:ok, host} = :inet.gethostname()

    host |> to_string
  end

  def clientside_data(conn) do
    extra = Map.get(conn.assigns, :clientside_data, [])
    interactions = Map.get(conn.assigns, :interactions, [])
    user = conn.assigns.current_user
    filter = conn.assigns.current_filter

    data = [
      filter_id: filter.id,
      hidden_tag_list: Jason.encode!(filter.hidden_tag_ids),
      hidden_filter: Search.String.normalize(filter.hidden_complex_str || ""),
      spoilered_tag_list: Jason.encode!(filter.spoilered_tag_ids),
      spoilered_filter: Search.String.normalize(filter.spoilered_complex_str || ""),
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
      ignored_tag_list: "[]"
    ]

    data = Keyword.merge(data, extra)

    tag(:div, class: "js-datastore", data: data)
  end

  def stylesheet_path(conn, %{theme: "dark"}),
    do: Routes.static_path(conn, "/css/dark.css")

  def stylesheet_path(conn, %{theme: "red"}),
    do: Routes.static_path(conn, "/css/red.css")

  def stylesheet_path(conn, _user),
    do: Routes.static_path(conn, "/css/default.css")
end
