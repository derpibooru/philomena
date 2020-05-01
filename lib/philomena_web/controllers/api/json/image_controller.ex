defmodule PhilomenaWeb.Api.Json.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.Interactions
  alias Philomena.Repo
  alias Philomena.Tags
  alias Philomena.UserStatistics
  import Ecto.Query

  plug :set_scraper_cache
  plug PhilomenaWeb.ApiRequireAuthorizationPlug when action in [:create]
  plug PhilomenaWeb.UserAttributionPlug when action in [:create]

  plug PhilomenaWeb.ScraperPlug,
       [params_name: "image", params_key: "image"] when action in [:create]

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    image =
      Image
      |> where(id: ^id)
      |> preload([:tags, :user, :intensity])
      |> Repo.one()

    case image do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("")

      _ ->
        interactions = Interactions.user_interactions([image], user)

        render(conn, "show.json", image: image, interactions: interactions)
    end
  end

  def create(conn, %{"image" => image_params}) do
    user = conn.assigns.current_user
    attributes = conn.assigns.attributes

    case Images.create_image(attributes, image_params) do
      {:ok, %{image: image}} ->
        spawn(fn ->
          Images.repair_image(image)
        end)

        # ImageProcessor.cast(image.id)
        Images.reindex_image(image)
        Tags.reindex_tags(image.added_tags)
        UserStatistics.inc_stat(user, :uploads)

        render(conn, "show.json", image: image, interactions: [])

      {:error, :image, changeset, _} ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", changeset: changeset)
    end
  end

  defp set_scraper_cache(conn, _opts) do
    params =
      conn.params
      |> Map.put_new("image", %{})
      |> Map.put("scraper_cache", conn.params["url"])

    %{conn | params: params}
  end
end
