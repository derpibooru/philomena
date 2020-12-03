defmodule PhilomenaWeb.Image.RelatedController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.Interactions
  alias Philomena.Images.Image
  alias Philomena.Elasticsearch
  import Ecto.Query

  plug PhilomenaWeb.CanaryMapPlug, index: :show

  plug :load_and_authorize_resource,
    model: Image,
    id_name: "image_id",
    persisted: true,
    preload: [:faves, tags: :aliases]

  def index(conn, _params) do
    image = conn.assigns.image
    user = conn.assigns.current_user

    tags_to_match =
      image.tags
      |> Enum.reject(&(&1.category == "rating"))
      |> Enum.sort_by(& &1.images_count)
      |> Enum.take(10)
      |> Enum.map(& &1.id)

    low_count_tags =
      tags_to_match
      |> Enum.take(5)
      |> Enum.map(&%{term: %{tag_ids: &1}})

    high_count_tags =
      tags_to_match
      |> Enum.take(-5)
      |> Enum.map(&%{term: %{tag_ids: &1}})

    favs_to_match =
      image.faves
      |> Enum.take(11)
      |> Enum.map(&%{term: %{favourited_by_user_ids: &1.user_id}})

    query = %{
      bool: %{
        must: [
          %{bool: %{should: low_count_tags, boost: 2}},
          %{bool: %{should: high_count_tags, boost: 3, minimum_should_match: "5%"}},
          %{bool: %{should: favs_to_match, boost: 0.2, minimum_should_match: "5%"}}
        ],
        must_not: %{term: %{id: image.id}}
      }
    }

    {images, _tags} =
      ImageLoader.query(
        conn,
        query,
        sorts: &%{query: &1, sorts: [%{_score: :desc}]},
        pagination: %{conn.assigns.image_pagination | page_number: 1}
      )

    images = Elasticsearch.search_records(images, preload(Image, tags: :aliases))

    interactions = Interactions.user_interactions(images, user)

    render(conn, "index.html",
      title: "##{image.id} - Related Images",
      layout_class: "wide",
      images: images,
      interactions: interactions
    )
  end
end
