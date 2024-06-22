defmodule Philomena.Adverts.Restrictions do
  @moduledoc """
  Advert restriction application.
  """

  @type restriction :: String.t()
  @type restriction_list :: [restriction()]
  @type tag_list :: [String.t()]

  @nsfw_tags MapSet.new(["questionable", "explicit"])
  @sfw_tags MapSet.new(["safe", "suggestive"])

  @doc """
  Calculates the restrictions available to a given tag list.

  Returns a list containing `"none"`, and neither or one of `"sfw"`, `"nsfw"`.

  ## Examples

      iex> tags([])
      ["none"]

      iex> tags(["safe"])
      ["sfw", "none"]

      iex> tags(["explicit"])
      ["nsfw", "none"]

  """
  @spec tags(tag_list()) :: restriction_list()
  def tags(tags) do
    tags = MapSet.new(tags)

    ["none"]
    |> apply_if(tags, @nsfw_tags, "nsfw")
    |> apply_if(tags, @sfw_tags, "sfw")
  end

  @spec apply_if(restriction_list(), MapSet.t(), MapSet.t(), restriction()) :: restriction_list()
  defp apply_if(restrictions, tags, test, new_restriction) do
    if MapSet.disjoint?(tags, test) do
      restrictions
    else
      [new_restriction | restrictions]
    end
  end
end
