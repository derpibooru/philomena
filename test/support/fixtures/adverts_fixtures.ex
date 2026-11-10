defmodule Philomena.AdvertsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.Adverts` context.
  """

  alias Philomena.Adverts.Advert
  alias Philomena.Repo
  alias PhilomenaMedia.Upload

  @doc """
  Creates an advert.

  `Adverts.create_advert/1` runs the image upload pipeline
  (`Uploader.analyze_upload/2` fails without a real uploaded file), which
  characterization tests don't need - so, like badges, this inserts the row
  directly with the image filename set the way the uploader would leave it.
  """
  def advert_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])
    now = DateTime.utc_now(:second)

    %Advert{image: "test.png"}
    |> Advert.changeset(
      Enum.into(attrs, %{
        title: "Test Advert #{unique}",
        link: "https://example.com/advert-target-#{unique}",
        start_date: DateTime.add(now, -1, :hour),
        finish_date: DateTime.add(now, 1, :hour),
        live: true,
        restrictions: "none"
      })
    )
    |> Repo.insert!()
  end

  @png_fixture Path.absname("test/support/fixtures/files/advert-test.png")
  @undersized_png_fixture Path.absname("test/support/fixtures/files/upload-test.png")

  @doc """
  A real 700x85 PNG upload - advert create/update-image run the media pipeline
  and the advert image_changeset validates width (699..729) and height
  (79..91).
  """
  def png_upload do
    # Copy into a tempfile: the upload pipeline may mutate or consume the file it
    # is given, and pointing at the tracked fixture corrupts the working tree.
    {:ok, path} = Plug.Upload.random_file("advert-upload-test")
    File.cp!(@png_fixture, path)
    %Plug.Upload{path: path, filename: "advert.png", content_type: "image/png"}
  end

  @doc """
  The shared 1x1 PNG - a valid PNG whose dimensions fail the advert
  width/height validations.
  """
  def undersized_png_upload do
    # Copy into a tempfile: the upload pipeline may mutate or consume the file it
    # is given, and pointing at the tracked fixture corrupts the working tree.
    {:ok, path} = Plug.Upload.random_file("advert-undersized-test")
    File.cp!(@undersized_png_fixture, path)
    %Plug.Upload{path: path, filename: "small.png", content_type: "image/png"}
  end

  def media_png_upload do
    Upload.from_plug(png_upload())
  end

  def media_undersized_png_upload do
    Upload.from_plug(undersized_png_upload())
  end
end
