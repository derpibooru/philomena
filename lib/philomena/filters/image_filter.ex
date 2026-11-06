defmodule Philomena.Filters.ImageFilter do
  @moduledoc """
  Generates the compiled image filter for a viewer.

  `query` is the OpenSearch clause used to exclude hidden images. The display
  fields contain the current filter's hidden/spoiler rules.
  """

  alias Philomena.Attribution.Actor
  alias Philomena.Filters.Filter
  alias Philomena.Images.Query
  alias PhilomenaQuery.Parse

  @enforce_keys [:query, :display_query, :display_tag_ids]
  defstruct [:query, :display_query, :display_tag_ids]

  @type t :: %__MODULE__{
          query: map(),
          display_query: map(),
          display_tag_ids: [integer()]
        }

  @spec compile(Actor.t(), Filter.t() | nil, Filter.t() | nil) :: t()
  def compile(%Actor{} = actor, current_filter, forced_filter) do
    current = defaults(current_filter)
    forced = defaults(forced_filter)

    hidden_query = %{
      bool: %{
        should: [
          compile_expression(actor, current.hidden_complex_str),
          compile_expression(actor, forced.hidden_complex_str)
        ]
      }
    }

    %__MODULE__{
      query: %{
        bool: %{
          should: [
            %{terms: %{tag_ids: current.hidden_tag_ids ++ forced.hidden_tag_ids}},
            hidden_query
          ]
        }
      },
      display_query: %{
        bool: %{
          should: [hidden_query, compile_expression(actor, current.spoilered_complex_str)]
        }
      },
      display_tag_ids: current.spoilered_tag_ids ++ current.hidden_tag_ids
    }
  end

  # An expression that does not compile for this viewer matches every image,
  # so an invalid hidden expression hides everything and an invalid spoiler
  # expression spoilers everything.
  defp compile_expression(actor, expression) do
    expression
    |> Parse.String.normalize()
    |> Query.compile(user: actor.user, filter: true)
    |> case do
      {:ok, query} -> query
      {:error, _reason} -> %{match_all: %{}}
    end
  end

  defp defaults(nil) do
    %{
      hidden_tag_ids: [],
      spoilered_tag_ids: [],
      hidden_complex_str: nil,
      spoilered_complex_str: nil
    }
  end

  defp defaults(%Filter{} = filter), do: filter
end
