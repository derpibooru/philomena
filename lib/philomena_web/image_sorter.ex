defmodule PhilomenaWeb.ImageSorter do
  @allowed_fields ~W(
    updated_at
    first_seen_at
    aspect_ratio
    faves
    downvotes
    upvotes
    width
    height
    score
    comment_count
    tag_count
    wilson_score
    pixels
    size
    duration
  )

  def parse_sort(params, query) do
    sd = parse_sd(params)

    parse_sf(params, sd, query)
  end

  defp parse_sd(%{"sd" => sd}) when sd in ~W(asc desc), do: sd
  defp parse_sd(_params), do: "desc"

  defp parse_sf(%{"sf" => sf}, sd, query) when sf in @allowed_fields do
    %{query: query, sorts: [%{sf => sd}, %{"id" => sd}]}
  end

  defp parse_sf(%{"sf" => "_score"}, sd, query) do
    %{query: query, sorts: [%{"_score" => sd}, %{"id" => sd}]}
  end

  defp parse_sf(%{"sf" => "random"}, sd, query) do
    random_query(:rand.uniform(4_294_967_296), sd, query)
  end

  defp parse_sf(%{"sf" => <<"random:", seed::binary>>}, sd, query) do
    case Integer.parse(seed) do
      {seed, _rest} ->
        random_query(seed, sd, query)

      _ ->
        random_query(:rand.uniform(4_294_967_296), sd, query)
    end
  end

  defp parse_sf(%{"sf" => <<"gallery_id:", gallery::binary>>}, sd, query) do
    case Integer.parse(gallery) do
      {gallery, _rest} ->
        %{
          query: query,
          sorts: [
            %{
              "galleries.position" => %{
                order: sd,
                nested: %{
                  path: :galleries,
                  filter: %{
                    term: %{"galleries.id" => gallery}
                  }
                }
              }
            },
            %{"id" => "desc"}
          ]
        }

      _ ->
        %{query: query, sorts: []}
    end
  end

  defp parse_sf(_params, sd, query) do
    %{query: query, sorts: [%{"id" => sd}]}
  end

  defp random_query(seed, sd, query) do
    %{
      query: %{
        function_score: %{
          query: query,
          random_score: %{seed: seed, field: :id},
          boost_mode: :replace
        }
      },
      sorts: [%{"_score" => sd}, %{"id" => sd}]
    }
  end
end
