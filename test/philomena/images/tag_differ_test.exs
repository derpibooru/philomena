defmodule Philomena.Images.TagDifferTest do
  @moduledoc """
  Tag edits through `Philomena.Images.update_image_tags/3`, where `TagDiffer`
  applies the canonical removed and added sets: a tag present in both survives.
  """

  use Philomena.DataCase, async: true

  import Ecto.Changeset
  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Images

  setup do
    %{actor: actor(confirmed_user_fixture())}
  end

  defp tag_names(image) do
    image
    |> Repo.preload(:tags, force: true)
    |> Map.fetch!(:tags)
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end

  defp edit_tags(actor, image, old_tag_input, tag_input) do
    Images.update_image_tags(actor, image.id, %{
      "old_tag_input" => old_tag_input,
      "tag_input" => tag_input
    })
  end

  test "replacing a tag with its alias keeps the tag", %{actor: actor} do
    canonical = tag_fixture()
    alias_tag = tag_fixture() |> change(aliased_tag_id: canonical.id) |> Repo.update!()
    old_input = "safe, cute, #{canonical.name}"
    image = image_fixture(tags: old_input)

    assert {:ok, _result} = edit_tags(actor, image, old_input, "safe, cute, #{alias_tag.name}")

    assert tag_names(image) == Enum.sort(["safe", "cute", canonical.name])
  end

  test "removing a tag while adding one that implies it keeps the implied tag", %{
    actor: actor
  } do
    implied = tag_fixture()

    implying =
      tag_fixture()
      |> Repo.preload(:implied_tags)
      |> change()
      |> put_assoc(:implied_tags, [implied])
      |> Repo.update!()

    old_input = "safe, cute, #{implied.name}"
    image = image_fixture(tags: old_input)

    assert {:ok, _result} = edit_tags(actor, image, old_input, "safe, cute, #{implying.name}")

    assert tag_names(image) == Enum.sort(["safe", "cute", implied.name, implying.name])
  end
end
