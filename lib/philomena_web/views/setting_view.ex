defmodule PhilomenaWeb.SettingView do
  use PhilomenaWeb, :view
  alias Philomena.Users.User

  def themes do
    [
      Dark: "dark",
      Light: "light"
    ]
  end

  def theme_colors do
    Enum.map(User.theme_colors(), fn name ->
      {String.capitalize(name), name}
    end)
  end

  def theme_paths_json(conn) do
    User.themes()
    |> Map.new(fn name ->
      {name, static_path(conn, "/css/#{name}.css")}
    end)
    |> Jason.encode!()
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
