defmodule PhilomenaWeb.FilterController do
  use PhilomenaWeb, :controller

  alias Philomena.Filters.Filter
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    user = conn.assigns.current_user

    my_filters =
      if user do
        Filter
        |> where(user_id: ^user.id)
        |> preload(:user)
        |> Repo.all()
      else
        []
      end

    system_filters =
      Filter
      |> where(system: true)
      |> preload(:user)
      |> Repo.all()

    render(conn, "index.html", my_filters: my_filters, system_filters: system_filters)
  end
end
