defmodule PhilomenaWeb.Filter.CurrentController do
  use PhilomenaWeb, :controller

  alias Philomena.{Filters, Filters.Filter}

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

    conn =
      if user do
        nil
      else
        conn
        |> put_session(:filter_id, filter.id)
      end

    conn
    |> put_flash(:info, "Switched to filter #{filter.name}")
    |> redirect(to: "/")
  end
end
