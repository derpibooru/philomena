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
      |> preload(game_profiles: :team)
      |> Repo.all()

    categories = [
      Administrators: Enum.filter(users, &(&1.role == "admin" and &1.hide_default_role == false)),
      "Technical Team":
        Enum.filter(
          users,
          &(&1.role != "admin" and &1.secondary_role in ["Site Developer", "Devops"])
        ),
      "Public Relations":
        Enum.filter(
          users,
          &(&1.role != "admin" and &1.secondary_role == "Public Relations" and
              &1.hide_default_role == false)
        ),
      Moderators:
        Enum.filter(
          users,
          &(&1.role == "moderator" and &1.secondary_role in [nil, ""] and
              &1.hide_default_role == false)
        ),
      Assistants:
        Enum.filter(
          users,
          &(&1.role == "assistant" and &1.secondary_role in [nil, ""] and
              &1.hide_default_role == false)
        ),
      Others:
        Enum.filter(
          users,
          &(&1.role != "user" and
              &1.secondary_role not in [nil, "", "Site Developer", "Devops", "Public Relations"] and
              &1.hide_default_role == true)
        ),
      "Unavailable Staff":
        Enum.filter(
          users,
          &(&1.role != "user" and
              &1.secondary_role in ["", nil] and
              &1.hide_default_role == true)
        )
    ]

    render(conn, "index.html", title: "Site Staff", categories: categories)
  end
end
