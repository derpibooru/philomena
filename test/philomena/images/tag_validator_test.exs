defmodule Philomena.Images.TagValidatorTest do
  use Philomena.DataCase, async: true

  alias Philomena.Images.Image
  alias Philomena.Tags.Tag

  defp tags(count) do
    [%Tag{id: 1, name: "safe"} | for(id <- 2..count, do: %Tag{id: id, name: "tag #{id}"})]
  end

  test "validates the final tag count on new images" do
    assert Image.tag_changeset(%Image{}, tags(6_000), []).valid?

    changeset = Image.tag_changeset(%Image{}, tags(6_001), [])
    assert "must contain at most 6000 tags" in errors_on(changeset).tag_input
  end

  test "counts existing and locked tags, allowing replacements at the limit" do
    tags = tags(6_000)
    image = %Image{tags: tags}
    new_tag = %Tag{id: 6_001, name: "new tag"}
    removed_tag = List.last(tags)

    assert Image.tag_changeset(image, [new_tag], [removed_tag]).valid?

    changeset = Image.tag_changeset(image, [new_tag], [removed_tag], [removed_tag])
    assert "must contain at most 6000 tags" in errors_on(changeset).tag_input
  end
end
