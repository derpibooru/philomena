defmodule Philomena.Tags.QuickTagTable do
  import Ecto.Query, warn: false

  alias Philomena.Config
  alias Philomena.Repo
  alias Philomena.Tags.Tag
  alias PhilomenaQuery.Search

  @persistent_key {__MODULE__, :table}

  @enforce_keys [:tags, :shipping, :data]
  defstruct [:tags, :shipping, :data]

  @type t :: %__MODULE__{
          tags: %{String.t() => Tag.t()},
          shipping: %{String.t() => [Tag.t()]},
          data: map()
        }

  @spec get() :: t()
  def get do
    case :persistent_term.get(@persistent_key, :missing) do
      :missing -> refresh()
      table -> table
    end
  end

  @spec refresh() :: t()
  def refresh do
    table = build(Config.get(:quick_tag_table))
    :persistent_term.put(@persistent_key, table)
    table
  end

  defp build(%{"tabs" => tabs, "tab_modes" => tab_modes} = data) do
    tags =
      tabs
      |> Enum.flat_map(&names_in_tab(tab_modes[&1], data[&1]))
      |> tags_indexed_by_name()

    shipping =
      tabs
      |> Enum.filter(&(tab_modes[&1] == "shipping"))
      |> Map.new(fn tab ->
        shipping_data = data[tab]

        {tab, implied_by_multitag(shipping_data["implying"], shipping_data["not_implying"])}
      end)

    %__MODULE__{tags: tags, shipping: shipping, data: data}
  end

  defp names_in_tab("default", data) do
    data
    |> Map.values()
    |> List.flatten()
  end

  defp names_in_tab("season", data), do: Enum.map(data, fn [_number, name] -> name end)

  defp names_in_tab("shorthand", data) do
    data
    |> Enum.map(fn [_title, tags] -> tags end)
    |> Enum.flat_map(&Enum.map(&1, fn [_shorthand, tag] -> tag end))
  end

  defp names_in_tab(_mode, _data), do: []

  defp tags_indexed_by_name(names) do
    Tag
    |> where([tag], tag.name in ^names)
    |> preload(:implied_tags)
    |> Repo.all()
    |> Map.new(&{&1.name, &1})
  end

  defp implied_by_multitag(tag_names, ignore_tag_names) do
    Tag
    |> Search.search_definition(
      %{
        query: %{
          bool: %{
            must: Enum.map(tag_names, &%{term: %{implied_tags: &1}}),
            must_not: Enum.map(ignore_tag_names, &%{term: %{implied_tags: &1}})
          }
        },
        sort: %{images: :desc}
      },
      %{page_size: 40}
    )
    |> Search.search_records(preload(Tag, :implied_tags))
  end
end
