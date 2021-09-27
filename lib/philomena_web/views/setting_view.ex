defmodule PhilomenaWeb.SettingView do
  use PhilomenaWeb, :view

  def theme_options(conn) do
    [
      [
        key: "Default",
        value: "default",
        data: [theme_path: Routes.static_path(conn, "/css/default.css")]
      ],
      [key: "Dark", value: "dark", data: [theme_path: Routes.static_path(conn, "/css/dark.css")]],
      [key: "Red", value: "red", data: [theme_path: Routes.static_path(conn, "/css/red.css")]]
    ]
  end

  def scale_options do
    [
      [key: "Load full images on image pages", value: "false"],
      [key: "Load full images on image pages, sized to fit the page", value: "partscaled"],
      [key: "Scale large images down before downloading", value: "true"]
    ]
  end

  def local_tab_class(conn) do
    case conn.assigns.current_user do
      nil -> ""
      _user -> "hidden"
    end
  end

  def staff?(%{role: role}), do: role != "user"
  def staff?(_), do: false
end
