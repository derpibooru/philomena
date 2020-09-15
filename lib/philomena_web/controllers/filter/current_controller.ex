defmodule PhilomenaWeb.Filter.CurrentController do
  use PhilomenaWeb, :controller

  @cookie_opts [max_age: 788_923_800, same_site: "Lax"]

  alias Philomena.{Filters, Filters.Filter, Users.User}
  alias Philomena.Repo

  plug :load_resource, model: Filter

  def update(conn, _params) do
    filter = conn.assigns.filter
    user = conn.assigns.current_user

    filter =
      if Canada.Can.can?(user, :show, filter) do
        filter
      else
        Filters.default_filter()
      end

    conn
    |> update_filter(user, filter)
    |> put_flash(:info, "Switched to filter #{filter.name}")
    |> redirect(external: conn.assigns.referrer)
  end

  defp update_filter(conn, nil, filter) do
    put_resp_cookie(conn, "filter_id", Integer.to_string(filter.id), @cookie_opts)
  end

  defp update_filter(conn, user, filter) do
    {:ok, _user} =
      user
      |> User.filter_changeset(filter)
      |> Repo.update()

    conn
  end
end
