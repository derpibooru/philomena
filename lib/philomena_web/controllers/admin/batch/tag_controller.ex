defmodule PhilomenaWeb.Admin.Batch.TagController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def update(conn, params) do
    case Images.update_batch_tags(conn.assigns.actor, params) do
      {:ok, result} ->
        json(conn, %{succeeded: result.succeeded, failed: result.failed})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:bad_request)
        |> put_view(PhilomenaWeb.Api.Json.ImageView)
        |> render("error.json", changeset: changeset)

      error ->
        error
    end
  end
end
