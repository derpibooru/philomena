defmodule PhilomenaWeb.Api.Json.ImageController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.Interactions
  alias Philomena.Repo
  alias Philomena.Tags
  alias Philomena.UserStatistics
  import Ecto.Query

  import EctoNetwork.INET

  plug :set_scraper_cache
  plug PhilomenaWeb.ScraperPlug, params_key: "image", params_name: "image"

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

  def create(conn, %{"image" => image_params} = params) do
    user = conn.assigns.current_user

    params =
      params
      |> Map.put("scraper_url", Map.get(params, "url"))
      |> Map.put("anonymous", Map.get(params, "anonymous", false))
      |> Map.put("source_url", Map.get(params, "source_url", ""))
      |> Map.put("description", Map.get(params, "description", ""))
      |> Map.merge(image_params)

    case user do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> text("")

      _ ->
        attributes = %{
          user: user,
          ip: decode_ip(conn.remote_ip),
          fingerprint: "c415049"
        }

        case Images.create_image(attributes, params) do
          {:ok, %{image: image}} ->
            spawn(fn ->
              Images.repair_image(image)
            end)

            # ImageProcessor.cast(image.id)
            Images.reindex_image(image)
            Tags.reindex_tags(image.added_tags)
            UserStatistics.inc_stat(user, :uploads)

            interactions = Interactions.user_interactions([image], user)

            conn
            |> put_view(PhilomenaWeb.Api.Json.ImageView)
            |> render("show.json", image: image, interactions: interactions)

          {:error, :image, changeset, _} ->
            IO.inspect(changeset, label: "Error")

            conn
            |> put_status(:bad_request)
            |> render("error.json", changeset: changeset)
        end
    end
  end

  defp set_scraper_cache(conn, _opts) do
    params =
      conn.params
      |> Map.put("image", %{})
      |> Map.put("scraper_cache", conn.params["url"])

    %{conn | params: params}
  end

  defp decode_ip(remote_ip) do
    case EctoNetwork.INET.cast(remote_ip) do
      {:ok, cast_ip} ->
        cast_ip

      _ ->
        nil
    end
  end
end
