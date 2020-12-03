defmodule PhilomenaWeb.SearchController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.Images.Image
  alias Philomena.Elasticsearch
  alias Philomena.Interactions
  import Ecto.Query

  def index(conn, params) do
    user = conn.assigns.current_user

    case ImageLoader.search_string(conn, params["q"]) do
      {:ok, {images, tags}} ->
        images = search_function(custom_ordering?(conn)).(images, preload(Image, tags: :aliases))
        interactions = Interactions.user_interactions(images, user)

        conn
        |> render("index.html",
          title: "Searching for #{params["q"]}",
          images: images,
          tags: tags,
          search_query: params["q"],
          interactions: interactions,
          layout_class: "layout--wide"
        )

      {:error, msg} ->
        render(conn, "index.html",
          title: "Searching for #{params["q"]}",
          images: [],
          error: msg,
          search_query: params["q"]
        )
    end
  end

  defp search_function(true), do: &Elasticsearch.search_records_with_hits/2
  defp search_function(_custom), do: &Elasticsearch.search_records/2

  defp custom_ordering?(%{params: %{"sf" => sf}}) when sf != "id", do: true
  defp custom_ordering?(_conn), do: false
end
