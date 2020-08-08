defmodule PhilomenaWeb.ImageNavigator do
  alias PhilomenaWeb.ImageSorter
  alias Philomena.Images.{Image, ElasticsearchIndex}
  alias Philomena.Elasticsearch
  alias Philomena.Repo
  import Ecto.Query

  # We get consecutive images by finding all images greater than or less than
  # the current image, and grabbing the FIRST one
  @range_comparison_for_order %{
    "asc" => :gt,
    "desc" => :lt
  }

  # If we didn't reverse for prev, it would be the LAST image, which would
  # make Elasticsearch choke on deep pagination
  @order_for_dir %{
    next: %{"asc" => "asc", "desc" => "desc"},
    prev: %{"asc" => "desc", "desc" => "asc"}
  }

  @range_map %{
    gt: :gte,
    lt: :lte
  }

  def find_consecutive(conn, image, rel, params, compiled_query, compiled_filter) do
    image_index =
      Image
      |> where(id: ^image.id)
      |> preload([:gallery_interactions, tags: :aliases])
      |> Repo.one()
      |> Map.merge(empty_fields())
      |> ElasticsearchIndex.as_json()

    %{query: compiled_query, sorts: sort} = ImageSorter.parse_sort(params, compiled_query)

    {sorts, filters} =
      sort
      |> Enum.map(&extract_filters(&1, image_index, rel))
      |> Enum.unzip()

    sorts = sortify(sorts, image_index)
    filters = filterify(filters, image_index)

    Elasticsearch.search_records(
      Image,
      %{
        query: %{
          bool: %{
            must: List.flatten([compiled_query, filters]),
            must_not: [
              compiled_filter,
              %{term: %{hidden_from_users: true}},
              hidden_filter(conn.assigns.current_user, conn.params["hidden"])
            ]
          }
        },
        sort: List.flatten(sorts)
      },
      %{page_size: 1},
      Image
    )
    |> Enum.to_list()
    |> case do
      [] -> image
      [next_image] -> next_image
    end
  end

  defp extract_filters(%{"galleries.position" => term} = sort, image, rel) do
    # Extract gallery ID and current position
    gid = term.nested.filter.term["galleries.id"]
    pos = Enum.find(image[:galleries], &(&1.id == gid)).position

    # Sort in the other direction if we are going backwards
    sd = term.order
    order = @order_for_dir[rel][to_string(sd)]
    term = %{term | order: order}
    sort = %{sort | "galleries.position" => term}

    filter = gallery_range_filter(@range_comparison_for_order[order], pos)

    {[sort], [filter]}
  end

  defp extract_filters(sort, image, rel) do
    [{sf, sd}] = Enum.to_list(sort)
    order = @order_for_dir[rel][sd]
    sort = %{sort | sf => order}

    field = String.to_existing_atom(sf)
    filter = range_filter(sf, @range_comparison_for_order[order], image[field])

    case sf do
      "_score" ->
        {[sort], []}

      _ ->
        {[sort], [filter]}
    end
  end

  defp sortify(sorts, _image) do
    List.flatten(sorts)
  end

  defp filterify(filters, image) do
    filters = List.flatten(filters)

    filters =
      filters
      |> Enum.with_index()
      |> Enum.map(fn
        {filter, 0} ->
          filter.this

        {filter, i} ->
          filters_so_far =
            filters
            |> Enum.take(i)
            |> Enum.map(& &1.for_next)

          %{
            bool: %{
              must: [filter.this | filters_so_far]
            }
          }
      end)

    %{
      bool: %{
        should: filters,
        must_not: %{term: %{id: image.id}}
      }
    }
  end

  defp hidden_filter(%{id: id}, param) when param != "1", do: %{term: %{hidden_by_user_ids: id}}
  defp hidden_filter(_user, _param), do: %{match_none: %{}}

  defp range_filter(sf, dir, val) do
    %{
      this: %{range: %{sf => %{dir => parse_val(val)}}},
      next: %{range: %{sf => %{@range_map[dir] => parse_val(val)}}}
    }
  end

  defp gallery_range_filter(dir, val) do
    %{
      this: %{
        nested: %{
          path: :galleries,
          query: %{range: %{"galleries.position" => %{dir => val}}}
        }
      },
      next: %{
        nested: %{
          path: :galleries,
          query: %{range: %{"galleries.position" => %{@range_map[dir] => val}}}
        }
      }
    }
  end

  defp empty_fields do
    %{
      user: nil,
      deleter: nil,
      upvoters: [],
      downvoters: [],
      favers: [],
      hiders: []
    }
  end

  defp parse_val(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp parse_val(value), do: value
end
