defmodule PhilomenaWeb.Admin.DonationController do
  use PhilomenaWeb, :controller

  alias Philomena.Donations.Donation
  alias Philomena.Donations
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized

  def index(conn, _params) do
    donations =
      Donation
      |> order_by(desc: :created_at, asc: :user_id)
      |> preload(:user)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html", title: "Admin - Donations", donations: donations)
  end

  def create(conn, %{"donation" => donation_params}) do
    case Donations.create_donation(donation_params) do
      {:ok, _donation} ->
        conn
        |> put_flash(:info, "Donation successfully created.")
        |> redirect(to: Routes.admin_donation_path(conn, :index))

      _error ->
        conn
        |> put_flash(:error, "Error creating donation!")
        |> redirect(to: Routes.admin_donation_path(conn, :index))
    end
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, Donation) do
      true -> conn
      _false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end
end
