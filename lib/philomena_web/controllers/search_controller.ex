defmodule PhilomenaWeb.SearchController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.{Image, Query}
  alias Philomena.Interactions

  import Ecto.Query

  def index(conn, params) do
    filter = conn.assigns.compiled_filter
    user = conn.assigns.current_user

    with {:ok, query} <- Query.compile(user, params["q"]) do
      sd = parse_sd(params)
      sf = parse_sf(params, sd)

      images =
        Image.search_records(
          %{
            query: %{bool: %{must: [query | sf.query], must_not: [filter, %{term: %{hidden_from_users: true}}]}},
            sort: sf.sort
          },
          conn.assigns.pagination,
          Image |> preload(:tags)
        )

      interactions =
        Interactions.user_interactions(images, user)

      conn
      |> render("index.html", images: images, search_query: params["q"], interactions: interactions, layout_class: "layout--wide")
    else
      {:error, msg} ->
        conn
        |> render("index.html",
          images: [],
          error: msg,
          search_query: params["q"]
        )
    end
  end

  defp parse_sd(%{"sd" => sd}) when sd in ~W(asc desc),
    do: sd
  defp parse_sd(_params), do: :desc

  defp parse_sf(%{"sf" => sf}, sd) when
    sf in ~W(created_at updated_at first_seen_at width height score comment_count tag_count wilson_score _score)
  do
    %{query: [], sort: %{sf => sd}}
  end

  defp parse_sf(%{"sf" => "random"}, sd) do
    random_query(:rand.uniform(4_294_967_296), sd)
  end

  defp parse_sf(%{"sf" => <<"random:", seed::binary>>}, sd) do
    case Integer.parse(seed) do
      {seed, _rest} ->
        random_query(seed, sd)

      _ ->
        random_query(:rand.uniform(4_294_967_296), sd)
    end
  end

  defp parse_sf(%{"sf" => <<"gallery_id:", gallery::binary>>}, sd) do
    case Integer.parse(gallery) do
      {gallery, _rest} ->
        %{
          query: [],
          sort: %{
            "galleries.position": %{
              order: sd,
              nested_path: :galleries,
              nested_filter: %{
                term: %{
                  "galleries.id": gallery
                }
              }
            }
          }
        }

      _ ->
        %{query: [], sort: %{match_none: %{}}}
    end
  end

  defp parse_sf(_params, sd) do
    %{query: [], sort: %{created_at: sd}}
  end

  defp random_query(seed, sd) do
    %{
      query: [%{
        function_score: %{
          query:        %{match_all: %{}},
          random_score: %{seed: seed},
          boost_mode:   :replace
        }
      }],
      sort: %{_score: sd}
    }
  end
end
