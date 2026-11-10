defmodule PhilomenaWeb.CommissionController do
  use PhilomenaWeb, :controller

  alias Philomena.Commissions

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, params) do
    with {:ok, directory} <-
           Commissions.list_commissions(
             conn.assigns.actor,
             query_param(params, "commission"),
             conn.assigns.scrivener
           ) do
      conn
      |> assign(:current_user, directory.current_user)
      |> render("index.html",
        title: "Commissions",
        commissions: directory.commissions,
        changeset: directory.changeset,
        layout_class: "layout--wide"
      )
    end
  end
end
