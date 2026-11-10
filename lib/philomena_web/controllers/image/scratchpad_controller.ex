defmodule PhilomenaWeb.Image.ScratchpadController do
  use PhilomenaWeb, :controller

  alias Philomena.Images

  action_fallback PhilomenaWeb.FallbackController

  def edit(conn, params) do
    with {:ok, image} <-
           Images.load_hidable_image(conn.assigns.actor, params["image_id"]) do
      changeset = Images.change_image(image)

      render(conn, "edit.html",
        title: "Editing Moderation Notes",
        image: image,
        changeset: changeset
      )
    end
  end

  def update(conn, %{"image" => image_params} = params) do
    with {:ok, image} <-
           Images.update_image_scratchpad(conn.assigns.actor, params["image_id"], image_params) do
      conn
      |> put_flash(:info, "Successfully updated moderation notes.")
      |> redirect(to: ~p"/images/#{image}")
    end
  end
end
