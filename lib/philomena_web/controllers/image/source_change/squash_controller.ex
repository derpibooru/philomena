defmodule PhilomenaWeb.Image.SourceChange.SquashController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"image_id" => image_id}) do
    with {:ok, image} <- Images.create_image_source_change_squash(conn.assigns.actor, image_id) do
      conn
      |> put_flash(:info, "Successfully squashed source changes.")
      |> redirect(to: ~p"/images/#{image}/source_changes")
    end
  end
end
