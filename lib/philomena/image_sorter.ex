defmodule Philomena.ImageSorter do
  def parse_sort(params) do
    sd = parse_sd(params)

    parse_sf(params, sd)
  end

  defp parse_sd(%{"sd" => sd}) when sd in ~W(asc desc), do: sd
  defp parse_sd(_params), do: "desc"

  defp parse_sf(%{"sf" => sf}, sd) when
    sf in ~W(created_at updated_at first_seen_at width height score comment_count tag_count wilson_score _score)
  do
    %{queries: [], sorts: [%{sf => sd}]}
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
          sorts: [%{
            "galleries.position" => %{
              order: sd,
              nested_path: :galleries,
              nested_filter: %{
                term: %{
                  "galleries.id": gallery
                }
              }
            }
          }]
        }

      _ ->
        %{queries: [%{match_none: %{}}], sorts: []}
    end
  end

  defp parse_sf(_params, sd) do
    %{queries: [], sorts: [%{"created_at" => sd}]}
  end

  defp random_query(seed, sd) do
    %{
      queries: [%{
        function_score: %{
          query:        %{match_all: %{}},
          random_score: %{seed: seed},
          boost_mode:   :replace
        }
      }],
      sorts: [%{"_score" => sd}]
    }
  end
end