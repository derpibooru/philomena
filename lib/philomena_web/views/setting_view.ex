defmodule PhilomenaWeb.SettingView do
  use PhilomenaWeb, :view

  def themes do
    [
      Dark: "dark",
      Light: "light"
    ]
  end

  def theme_colors do
    [
      Red: "red",
      Orange: "orange",
      Yellow: "yellow",
      Green: "green",
      Blue: "blue",
      Purple: "purple",
      Cyan: "cyan",
      Pink: "pink",
      "Silver/Charcoal": "silver"
    ]
  end

  def theme_paths_json do
    Jason.encode!(%{
      "dark-red": ~p"/css/dark-red.css",
      "dark-orange": ~p"/css/dark-orange.css",
      "dark-yellow": ~p"/css/dark-yellow.css",
      "dark-blue": ~p"/css/dark-blue.css",
      "dark-green": ~p"/css/dark-green.css",
      "dark-purple": ~p"/css/dark-purple.css",
      "dark-cyan": ~p"/css/dark-cyan.css",
      "dark-pink": ~p"/css/dark-pink.css",
      "dark-silver": ~p"/css/dark-silver.css",
      "light-red": ~p"/css/light-red.css",
      "light-orange": ~p"/css/light-orange.css",
      "light-yellow": ~p"/css/light-yellow.css",
      "light-blue": ~p"/css/light-blue.css",
      "light-green": ~p"/css/light-green.css",
      "light-purple": ~p"/css/light-purple.css",
      "light-cyan": ~p"/css/light-cyan.css",
      "light-pink": ~p"/css/light-pink.css",
      "light-silver": ~p"/css/light-silver.css"
    })
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
