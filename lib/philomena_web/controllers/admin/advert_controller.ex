defmodule PhilomenaWeb.Admin.AdvertController do
  use PhilomenaWeb, :controller

  alias Philomena.Adverts.Advert
  alias Philomena.Adverts
  alias Philomena.Repo
  import Ecto.Query

  plug :verify_authorized
  plug :load_and_authorize_resource, model: Advert, only: [:edit, :update, :delete]

  def index(conn, _params) do
    adverts =
      Advert
      |> order_by(desc: :finish_date)
      |> Repo.paginate(conn.assigns.scrivener)

    render(conn, "index.html",
      title: "Admin - Adverts",
      layout_class: "layout--wide",
      adverts: adverts
    )
  end

  def new(conn, _params) do
    changeset = Adverts.change_advert(%Advert{})
    render(conn, "new.html", title: "New Advert", changeset: changeset)
  end

  def create(conn, %{"advert" => advert_params}) do
    case Adverts.create_advert(advert_params) do
      {:ok, advert} ->
        conn
        |> put_flash(:info, "Advert was successfully created.")
        |> moderation_log(details: &log_details/2, data: advert)
        |> redirect(to: ~p"/admin/adverts")

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = Adverts.change_advert(conn.assigns.advert)
    render(conn, "edit.html", title: "Editing Advert", changeset: changeset)
  end

  def update(conn, %{"advert" => advert_params}) do
    case Adverts.update_advert(conn.assigns.advert, advert_params) do
      {:ok, advert} ->
        conn
        |> put_flash(:info, "Advert was successfully updated.")
        |> moderation_log(details: &log_details/2, data: advert)
        |> redirect(to: ~p"/admin/adverts")

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, advert} = Adverts.delete_advert(conn.assigns.advert)

    conn
    |> put_flash(:info, "Advert was successfully deleted.")
    |> moderation_log(details: &log_details/2, data: advert)
    |> redirect(to: ~p"/admin/adverts")
  end

  defp verify_authorized(conn, _opts) do
    case Canada.Can.can?(conn.assigns.current_user, :index, Advert) do
      true -> conn
      false -> PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(action, advert) do
    body =
      case action do
        :create -> "Created advert #{advert.id}"
        :update -> "Updated advert #{advert.id}"
        :delete -> "Deleted advert #{advert.id}"
      end

    %{body: body, subject_path: ~p"/admin/adverts"}
  end
end
