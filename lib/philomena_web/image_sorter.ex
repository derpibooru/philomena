defmodule PhilomenaWeb.ImageSorter do
  @allowed_fields ~W(
    created_at
    updated_at
    first_seen_at
    aspect_ratio
    faves
    id
    downvotes
    upvotes
    width
    height
    score
    comment_count
    tag_count
    wilson_score
  )

  def parse_sort(params) do
    sd = parse_sd(params)

    parse_sf(params, sd)
  end

  defp parse_sd(%{"sd" => sd}) when sd in ~W(asc desc), do: sd
  defp parse_sd(_params), do: "desc"

  defp parse_sf(%{"sf" => sf}, sd) when sf in @allowed_fields do
    %{queries: [], sorts: [%{sf => sd}], constant_score: true}
  end

  defp parse_sf(%{"sf" => "_score"}, sd) do
    %{queries: [], sorts: [%{"_score" => sd}], constant_score: false}
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
          queries: [],
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
            }
          ],
          constant_score: true
        }

      _ ->
        %{queries: [%{match_none: %{}}], sorts: [], constant_score: true}
    end
  end

  defp parse_sf(_params, sd) do
    %{queries: [], sorts: [%{"created_at" => sd}], constant_score: true}
  end

  defp random_query(seed, sd) do
    %{
      queries: [
        %{
          function_score: %{
            query: %{match_all: %{}},
            random_score: %{seed: seed, field: :id},
            boost_mode: :replace
          }
        }
      ],
      sorts: [%{"_score" => sd}],
      constant_score: true
    }
  end
end
