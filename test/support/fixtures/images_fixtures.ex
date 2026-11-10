defmodule Philomena.ImagesFixtures do
  @moduledoc """
  This module defines test helpers for creating images.

  `Philomena.Images.create_image/2` requires a real uploaded file and drives
  the whole media pipeline (analysis, S3 persistence, thumbnailing,
  OpenSearch reindexing), which controller characterization tests don't
  need. This fixture inserts the row directly instead, with fields set the
  way the pipeline would leave them for a small processed PNG.
  """

  import Ecto.Changeset

  alias Philomena.Images.Image
  alias Philomena.Images.Source
  alias Philomena.Repo
  alias Philomena.TagsFixtures
  alias PhilomenaMedia.Upload
  alias PhilomenaMedia.Sha512

  @doc """
  Inserts a processed 100x100 PNG image.

  Override any `Image` field via `attrs`. Two pseudo-attributes are handled
  separately:

    * `tags:` a tag list string (default `"safe"`), created on demand via
      `TagsFixtures.tag_list_fixture/1`
    * `sources:` a list of source URL strings (default `[]`)
  """
  def image_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    {tag_input, attrs} = Map.pop(attrs, :tags, "safe")
    {sources, attrs} = Map.pop(attrs, :sources, [])

    sha512 = :sha512 |> :crypto.hash("#{System.unique_integer()}") |> Base.encode16(case: :lower)

    defaults = %{
      image: "test.png",
      image_name: "test.png",
      image_width: 100,
      image_height: 100,
      image_aspect_ratio: 1.0,
      image_size: 1024,
      image_orig_size: 1024,
      image_format: "png",
      image_mime_type: "image/png",
      image_duration: 0.0,
      image_is_animated: false,
      image_sha512_hash: sha512,
      image_orig_sha512_hash: sha512,
      ip: %Postgrex.INET{address: {203, 0, 113, 1}, netmask: 32},
      fingerprint: "d015c342859dde3",
      first_seen_at: DateTime.truncate(DateTime.utc_now(), :second),
      processed: true,
      thumbnails_generated: true,
      duplication_checked: true,
      approved: true
    }

    %Image{}
    |> change(Map.merge(defaults, attrs))
    |> put_assoc(:tags, TagsFixtures.tag_list_fixture(tag_input))
    |> put_assoc(:sources, Enum.map(sources, &%Source{source: &1}))
    |> Repo.insert!()
  end

  @png_fixture Path.absname("test/support/fixtures/files/upload-test.png")

  @doc """
  Builds a `%Plug.Upload{}` for the shared 100x100 PNG fixture, with its
  tempfile registered to the calling process the way `Plug.Parsers` would.

  Use this for actions that drive the media pipeline (e.g. replacing an
  image's file via `Image.FileController`).
  """
  def png_upload do
    {:ok, path} = Plug.Upload.random_file("image-upload-test")
    File.cp!(@png_fixture, path)
    %Plug.Upload{path: path, content_type: "image/png", filename: "upload-test.png"}
  end

  def media_png_upload do
    Upload.from_plug(png_upload())
  end

  @doc """
  The SHA-512 hash `analyze_upload` computes for `png_upload/0`'s file - i.e.
  the value an image's `image_orig_sha512_hash`/`image_sha512_hash` takes on
  once its file is replaced with that upload.

  Use it to arrange dedup-on-replace scenarios: seed an image (or a *different*
  image) with this hash to make a replacement byte-identical to an existing
  file.
  """
  def png_upload_sha512 do
    Sha512.file(@png_fixture)
  end
end
