defmodule PhilomenaWeb.Image.ScratchpadController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images

  plug PhilomenaWeb.CanaryMapPlug, edit: :hide, update: :hide
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def edit(conn, _params) do
    changeset = Images.change_image(conn.assigns.image)
    render(conn, "edit.html", title: "Editing Moderation Notes", changeset: changeset)
  end

  def update(conn, %{"image" => image_params}) do
    {:ok, image} = Images.update_scratchpad(conn.assigns.image, image_params)

    conn
    |> put_flash(:info, "Successfully updated moderation notes.")
    |> moderation_log(details: &log_details/2, data: image)
    |> redirect(to: ~p"/images/#{image}")
  end

  defp log_details(_action, image) do
    %{
      body: "Updated mod notes on image >>#{image.id} (#{image.scratchpad})",
      subject_path: ~p"/images/#{image}"
    }
  end
end
