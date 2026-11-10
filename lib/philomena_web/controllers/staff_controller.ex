defmodule PhilomenaWeb.StaffController do
  use PhilomenaWeb, :controller

  alias Philomena.Users

  def index(conn, _params) do
    render(conn, "index.html", title: "Site Staff", categories: Users.staff_categories())
  end
end
