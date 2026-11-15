defmodule PhilomenaWeb.Image.TagChange.SquashController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def create(conn, %{"image_id" => image_id}) do
    with {:ok, image} <- Images.create_image_tag_change_squash(conn.assigns.actor, image_id) do
      conn
      |> put_flash(:info, "Successfully squashed tag changes.")
      |> redirect(to: ~p"/images/#{image}/tag_changes")
    end
  end
end
