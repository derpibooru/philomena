defmodule PhilomenaWeb.CommissionController do
  use PhilomenaWeb, :controller

  alias Philomena.Commissions.SearchQuery
  alias Philomena.Commissions
  alias Philomena.Repo

  plug PhilomenaWeb.MapParameterPlug, [param: "commission"] when action in [:index]
  plug :preload_commission

  def index(conn, params) do
    commission_params = Map.get(params, "commission", %{})

    {commissions, changeset} =
      case Commissions.execute_search_query(commission_params) do
        {:ok, commissions} ->
          commissions = Repo.paginate(commissions, conn.assigns.scrivener)
          changeset = Commissions.change_search_query(%SearchQuery{})
          {commissions, changeset}

        {:error, changeset} ->
          {[], changeset}
      end

    render(conn, "index.html",
      title: "Commissions",
      commissions: commissions,
      changeset: changeset,
      layout_class: "layout--wide"
    )
  end

  defp preload_commission(conn, _opts) do
    user = conn.assigns.current_user

    case user do
      nil ->
        conn

      user ->
        user = Repo.preload(user, :commission)

        assign(conn, :current_user, user)
    end
  end
end
