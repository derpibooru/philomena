defmodule Philomena.BadgesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Badges` context.
  """

  alias Philomena.Badges.Award
  alias Philomena.Badges.Badge
  alias Philomena.Repo
  alias PhilomenaMedia.Upload

  def unique_badge_title, do: "Test Badge #{System.unique_integer([:positive])}"

  @doc """
  Creates a badge.

  `Badges.create_badge/1` runs the SVG upload pipeline
  (`persist_upload/1` crashes without a real uploaded file), which
  characterization tests don't need - so this inserts the row directly with
  the image filename set the way the uploader would leave it.
  """
  def badge_fixture(attrs \\ %{}) do
    %Badge{image: "test.svg"}
    |> Badge.changeset(Enum.into(attrs, %{title: unique_badge_title()}))
    |> Repo.insert!()
  end

  @doc """
  Awards `badge` (a fresh `badge_fixture/0` when `nil`) to `user`, awarded
  by `creator`.
  """
  def badge_award_fixture(creator, user, badge \\ nil, attrs \\ %{}) do
    badge = badge || badge_fixture()

    %Award{awarded_by_id: creator.id, user_id: user.id}
    |> Award.changeset(Enum.into(attrs, %{badge_id: badge.id}))
    |> Repo.insert!()
  end

  @svg_fixture Path.absname("test/support/fixtures/files/badge-test.svg")

  @doc """
  A real SVG upload - badge create/update-image run the media pipeline and the
  badge image_changeset requires an `image/svg+xml` MIME type.
  """
  def svg_upload do
    # Copy into a tempfile: the upload pipeline may mutate or consume the file it
    # is given, and pointing at the tracked fixture corrupts the working tree.
    {:ok, path} = Plug.Upload.random_file("badge-upload-test")
    File.cp!(@svg_fixture, path)
    %Plug.Upload{path: path, filename: "badge.svg", content_type: "image/svg+xml"}
  end

  def media_svg_upload do
    Upload.from_plug(svg_upload())
  end
end
