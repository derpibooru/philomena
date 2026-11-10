defmodule Philomena.TagsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Tags` context.
  """

  alias Philomena.Repo
  alias Philomena.Multi
  alias Philomena.Tags
  alias Philomena.Tags.Tag

  def unique_tag_name, do: "test tag #{System.unique_integer([:positive])}"

  def tag_list_fixture(tag_input) do
    {:ok, %{canonical_tags: %{tags: tags}}} =
      Multi.new()
      |> Tags.put_canonicalize_tag_name_sets([
        {:tags, Tag.parse_tag_list(tag_input), allow_insert_new?: true}
      ])
      |> Multi.transact()

    tags
  end

  @doc """
  Creates a tag.

  The creation changeset accepts only `:name` (slug, namespace, and namespace
  category are derived from it). Fixture persistence is direct so production
  does not expose raw CRUD solely for tests. A non-namespace `category:` attr
  is applied with a direct update afterwards, the way the tag controller would.
  """
  def tag_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: unique_tag_name()})
    {category, attrs} = Map.pop(attrs, :category)

    {:ok, tag} = %Tag{} |> Tag.creation_changeset(attrs) |> Repo.insert()

    case category do
      nil ->
        tag

      category ->
        tag
        |> Ecto.Changeset.change(category: category)
        |> Repo.update!()
    end
  end
end
