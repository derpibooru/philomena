defmodule PhilomenaWeb.Api.Json.ImageController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageJson
  alias Philomena.Images.Image

  plug :load_and_authorize_resource, model: Image, only: [:show], preload: [:tags, :user, :intensity]

  def show(conn, _params) do
    json(conn, %{image: ImageJson.as_json(conn, conn.assigns.image)})
  end
end
