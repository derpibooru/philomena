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
  defstruct [:query, :display_query, :display_tag_ids, errors: []]

  @type error :: {:hidden_complex_str | :spoilered_complex_str, String.t()}

  @type t :: %__MODULE__{
          query: map(),
          display_query: map(),
          display_tag_ids: [integer()],
          errors: [error()]
        }

  @spec compile(Actor.t(), Filter.t() | nil, Filter.t() | nil) :: t()
  def compile(%Actor{} = actor, current_filter, forced_filter) do
    current = defaults(current_filter)
    forced = defaults(forced_filter)

    {current_hidden, current_hidden_errors} =
      compile_expression(actor, :hidden_complex_str, current.hidden_complex_str)

    {forced_hidden, forced_hidden_errors} =
      compile_expression(actor, :hidden_complex_str, forced.hidden_complex_str)

    {current_spoiler, current_spoiler_errors} =
      compile_expression(actor, :spoilered_complex_str, current.spoilered_complex_str)

    hidden_query = %{bool: %{should: [current_hidden, forced_hidden]}}

    %__MODULE__{
      query: %{
        bool: %{
          should: [
            %{terms: %{tag_ids: current.hidden_tag_ids ++ forced.hidden_tag_ids}},
            hidden_query
          ]
        }
      },
      display_query: %{bool: %{should: [hidden_query, current_spoiler]}},
      display_tag_ids: current.spoilered_tag_ids ++ current.hidden_tag_ids,
      errors: current_hidden_errors ++ forced_hidden_errors ++ current_spoiler_errors
    }
  end

  # An expression that does not compile for this viewer matches every image,
  # so an invalid hidden expression hides everything and an invalid spoiler
  # expression spoilers everything. The error is kept for display.
  defp compile_expression(actor, field, expression) do
    expression
    |> Parse.String.normalize()
    |> Query.compile(user: actor.user, filter: true)
    |> case do
      {:ok, query} -> {query, []}
      {:error, message} -> {%{match_all: %{}}, [{field, message}]}
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
