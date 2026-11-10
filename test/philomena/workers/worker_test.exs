defmodule Philomena.WorkerTest do
  use Philomena.DataCase, async: false
  use Patch

  @moduletag :search

  import Philomena.ImagesFixtures

  alias Philomena.ImagePurgeWorker
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Images.Thumbnailer
  alias Philomena.IndexWorker
  alias Philomena.ThumbnailWorker
  alias Philomena.UserRenameWorker
  alias PhilomenaQuery.Search

  @index_contexts [
    {"Comments", Philomena.Comments},
    {"Filters", Philomena.Filters},
    {"Galleries", Philomena.Galleries},
    {"Images", Philomena.Images},
    {"Posts", Philomena.Posts},
    {"Reports", Philomena.Reports},
    {"TagChanges", Philomena.TagChanges},
    {"Tags", Philomena.Tags},
    {"Users", Philomena.Users}
  ]

  @rename_contexts [
    Philomena.Images,
    Philomena.Comments,
    Philomena.Posts,
    Philomena.Galleries,
    Philomena.Reports,
    Philomena.Filters,
    Philomena.TagChanges,
    Philomena.Users
  ]

  setup do
    Search.clear_index!(Image)
    :ok
  end

  defp assert_exact_call(module, function, arguments) do
    call = {function, arguments}
    assert Enum.count(history(module), &(&1 == call)) == 1
  end

  test "the index worker indexes matching records" do
    image = image_fixture()

    assert :ok = IndexWorker.perform("Images", "id", [image.id])
    :ok = Search.refresh_index!(Image)

    hits = Search.search(Image, %{query: %{match_all: %{}}})["hits"]["hits"]
    assert Enum.any?(hits, &(&1["_id"] == to_string(image.id)))
  end

  test "the index worker routes every job name to its context" do
    Enum.each(@index_contexts, fn {_name, context} ->
      patch(context, :perform_reindex, :ok)
    end)

    Enum.each(@index_contexts, fn {name, _context} ->
      assert :ok = IndexWorker.perform(name, "id", [123])
    end)

    Enum.each(@index_contexts, fn {_name, context} ->
      assert_exact_call(context, :perform_reindex, [:id, [123]])
    end)
  end

  test "the thumbnail worker generates media, broadcasts completion, and reindexes" do
    image = %Image{id: 321}
    patch(Thumbnailer, :generate_thumbnails, :ok)
    patch(Images, :load_image_for_reindex!, image)
    patch(Images, :reindex_image, image)

    assert image == ThumbnailWorker.perform(image.id)

    assert_exact_call(Thumbnailer, :generate_thumbnails, [image.id])
    assert_exact_call(Images, :load_image_for_reindex!, [image.id])
    assert_exact_call(Images, :reindex_image, [image])
  end

  test "the purge worker passes the complete file list to the purge operation" do
    files = ["/img/1/full.png", "/img/1/thumb.png"]
    patch(System, :cmd, {"", 0})

    assert :ok = ImagePurgeWorker.perform(files)

    assert_exact_call(System, :cmd, [
      "purge-cache",
      [JSON.encode!(%{files: files})]
    ])
  end

  test "the rename worker updates every index containing a user name" do
    Enum.each(@rename_contexts, &patch(&1, :user_name_reindex, :ok))

    assert :ok = UserRenameWorker.perform("Old Name", "New Name")

    Enum.each(@rename_contexts, fn context ->
      assert_exact_call(context, :user_name_reindex, ["Old Name", "New Name"])
    end)
  end
end
