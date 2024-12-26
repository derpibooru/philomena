defmodule PhilomenaWeb.ThemeController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.SettingView

  def index(conn, _params) do
    json(conn, SettingView.theme_paths())
  end
end
