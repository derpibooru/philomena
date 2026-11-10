defmodule Philomena.Images.Filtering do
  @moduledoc """
  In-memory image filtering owned by the Images domain.

  The same document shape supports presentation filtering and enforcement of a
  signed-in user's forced filter. Request controllers must call an owning
  context action rather than invoke this module to enforce access.
  """

  alias Philomena.Attribution.Actor
  alias Philomena.Filters.Filter
  alias Philomena.Filters.ImageFilter
  alias Philomena.Images.{Image, Query}
  alias Philomena.Repo
  alias Philomena.Users.User
  alias PhilomenaQuery.Parse.{Evaluator, String}

  defp load_forced_filter(%User{forced_filter_id: nil}), do: nil
  defp load_forced_filter(%User{forced_filter_id: filter_id}), do: Repo.get(Filter, filter_id)

  defp matches_filter?(user, image, filter) do
    matches_tag_filter?(image, filter.hidden_tag_ids) or
      matches_complex_filter?(user, image, filter.hidden_complex_str)
  end

  defp matches_tag_filter?(image, tag_ids) do
    image.tags
    |> MapSet.new(& &1.id)
    |> MapSet.intersection(MapSet.new(tag_ids))
    |> Enum.any?()
  end

  defp matches_complex_filter?(user, image, search_string) do
    image
    |> document()
    |> Evaluator.hits?(compile_filter(user, search_string))
  end

  defp compile_filter(user, search_string) do
    search_string
    |> String.normalize()
    |> Query.compile(user: user, filter: true)
    |> case do
      {:ok, query} -> query
      _error -> %{match_all: %{}}
    end
  end

  @doc """
  Builds the document evaluated by image filter expressions.

  `image.tags` and their aliases must be preloaded.

  ## Examples

      iex> document(image)
      %{id: 42, tags: "safe", ...}

  """
  @spec document(Image.t()) :: map()
  def document(%Image{} = image) do
    %{
      id: image.id,
      tags: image.tags |> Enum.flat_map(&([&1] ++ &1.aliases)) |> Enum.map_join(", ", & &1.name),
      tag_count: length(image.tags),
      score: image.score,
      faves: image.faves_count,
      upvotes: image.upvotes_count,
      downvotes: image.downvotes_count,
      comment_count: image.comments_count,
      created_at: image.created_at,
      first_seen_at: image.first_seen_at,
      source_url: image.source_url,
      width: image.image_width,
      height: image.image_height,
      aspect_ratio: image.image_aspect_ratio,
      sha512_hash: image.image_sha512_hash,
      orig_sha512_hash: image.image_orig_sha512_hash,
      description: image.description
    }
  end

  @doc """
  Returns whether an image matches the viewer's current hidden or spoiler
  display policy.

  The image's tags and aliases must be preloaded.
  """
  @spec filter_or_spoiler_hits?(Image.t(), ImageFilter.t()) :: boolean()
  def filter_or_spoiler_hits?(%Image{} = image, %ImageFilter{} = image_filter) do
    image_tag_ids = MapSet.new(image.tags, & &1.id)
    display_tag_ids = MapSet.new(image_filter.display_tag_ids)

    not MapSet.disjoint?(image_tag_ids, display_tag_ids) or
      Evaluator.hits?(document(image), image_filter.display_query)
  end

  @doc """
  Verifies that `image` does not match `actor`'s forced filter.

  Anonymous actors and users without a forced filter are permitted. Hidden tag
  IDs and the hidden complex expression are both enforced. Invalid stored filter
  expressions fail closed.

  ## Examples

      iex> verify_not_forced(actor, image)
      :ok

      iex> verify_not_forced(forced_actor, filtered_image)
      {:error, :forced_filter}

  """
  @spec verify_not_forced(Actor.t(), Image.t()) :: :ok | {:error, :forced_filter}
  def verify_not_forced(%Actor{user: nil}, %Image{}), do: :ok

  def verify_not_forced(%Actor{user: %User{} = user}, %Image{} = image) do
    case load_forced_filter(user) do
      nil ->
        :ok

      filter ->
        image = Repo.preload(image, tags: :aliases)

        if matches_filter?(user, image, filter),
          do: {:error, :forced_filter},
          else: :ok
    end
  end
end
