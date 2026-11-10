defmodule Philomena.DuplicateReports.ComparisonTest do
  use ExUnit.Case, async: true

  alias Philomena.DuplicateReports.Comparison
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Images.Image
  alias Philomena.Images.Source
  alias Philomena.Tags.Tag

  defp report(source_attrs \\ %{}, target_attrs \\ %{}) do
    source =
      struct!(
        %Image{
          id: 1,
          approved: true,
          image_width: 100,
          image_height: 100,
          image_aspect_ratio: 1.0,
          image_mime_type: "image/jpeg",
          sources: [],
          tags: [%Tag{name: "safe", category: "rating"}]
        },
        source_attrs
      )

    target =
      struct!(
        %Image{
          id: 2,
          approved: true,
          image_width: 200,
          image_height: 200,
          image_aspect_ratio: 1.0,
          image_mime_type: "image/png",
          sources: [],
          tags: [%Tag{name: "safe", category: "rating"}]
        },
        target_attrs
      )

    %DuplicateReport{
      image_id: source.id,
      duplicate_of_image_id: target.id,
      image: source,
      duplicate_of_image: target
    }
  end

  test "compares resolution, format, and merge direction" do
    report = report()

    assert Comparison.forward_merge?(report)
    assert Comparison.higher_res?(report)
    refute Comparison.same_res?(report)
    assert Comparison.better_format?(report)
    assert Comparison.same_aspect_ratio?(report)
  end

  test "compares source identity and host similarity" do
    source = [%Source{source: "https://example.com/a"}]
    same = [%Source{source: "https://example.com/a"}]
    similar = [%Source{source: "https://example.com/b"}]

    assert Comparison.same_source?(report(%{sources: source}, %{sources: same}))
    assert Comparison.similar_source?(report(%{sources: source}, %{sources: similar}))
    assert Comparison.source_on_target?(report(%{sources: []}, %{sources: similar}))
  end

  test "compares artist, rating, edit, and alternate-version tags" do
    safe = %Tag{name: "safe", category: "rating"}
    artist = %Tag{name: "artist:test", namespace: "artist"}
    edit = %Tag{name: "edit"}
    alternate = %Tag{name: "alternate version"}

    report = report(%{tags: [safe, artist]}, %{tags: [safe, artist, edit, alternate]})

    assert Comparison.same_artist_tags?(report)
    assert Comparison.same_rating_tags?(report)
    assert Comparison.target_is_edit?(report)
    assert Comparison.target_is_alternate_version?(report)
    refute Comparison.source_is_edit?(report)
  end

  test "requires matching ratings and two visible approved images for merging" do
    assert Comparison.mergeable?(report())
    refute Comparison.mergeable?(report(%{approved: false}))
    refute Comparison.mergeable?(report(%{hidden_from_users: true}))

    questionable = %Tag{name: "questionable", category: "rating"}
    refute Comparison.mergeable?(report(%{}, %{tags: [questionable]}))
  end
end
