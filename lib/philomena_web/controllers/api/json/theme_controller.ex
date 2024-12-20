defmodule PhilomenaWeb.Api.Json.ThemeController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.SettingView

  def index(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, SettingView.theme_paths_json(conn))
  end
end
