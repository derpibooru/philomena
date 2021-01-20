defmodule PhilomenaWeb.StaffController do
  use PhilomenaWeb, :controller

  alias Philomena.Users.User
  alias Philomena.Repo
  import Ecto.Query

  def index(conn, _params) do
    users =
      User
      |> where([u], u.role in ["admin", "moderator", "assistant"])
      |> order_by(asc: :name)
      |> Repo.all()

    categories = [
      Administrators: Enum.filter(users, &(&1.role == "admin")),
      "Technical Team":
        Enum.filter(
          users,
          &(&1.role != "admin" and &1.secondary_role in ["Site Developer", "Devops"])
        ),
      "Public Relations":
        Enum.filter(users, &(&1.role != "admin" and &1.secondary_role == "Public Relations")),
      Moderators:
        Enum.filter(
          users,
          &(&1.role == "moderator" and &1.secondary_role in [nil, ""])
        ),
      Assistants:
        Enum.filter(
          users,
          &(&1.role == "assistant" and &1.secondary_role in [nil, ""])
        )
    ]

    render(conn, "index.html", title: "Site Staff", categories: categories)
  end
end
