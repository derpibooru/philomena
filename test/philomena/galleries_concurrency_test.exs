defmodule Philomena.GalleriesConcurrencyTest do
  use Philomena.ConcurrentDataCase

  import Philomena.AttributionFixtures, only: [actor: 1]
  import Philomena.GalleriesFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Galleries
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries.Interaction
  alias Philomena.Repo

  test "concurrent additions of the same image create one membership" do
    user = confirmed_user_fixture()
    gallery = gallery_fixture(user)
    image = image_fixture()

    results =
      concurrently([
        fn -> Galleries.create_gallery_image(actor(user), gallery.id, image.id) end,
        fn -> Galleries.create_gallery_image(actor(user), gallery.id, image.id) end
      ])

    assert Enum.count(results, &match?({:ok, %Gallery{}}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Ecto.Changeset{}}, &1)) == 1
    assert Repo.aggregate(Interaction, :count) == 1
    assert Repo.get!(Gallery, gallery.id).image_count == 1
  end

  test "adding an image concurrently with deleting its gallery is serialized" do
    user = confirmed_user_fixture()
    gallery = gallery_fixture(user)
    image = image_fixture()

    [add_result, delete_result] =
      concurrently([
        fn -> Galleries.create_gallery_image(actor(user), gallery.id, image.id) end,
        fn -> Galleries.delete_gallery(actor(user), gallery.id) end
      ])

    assert match?({:ok, %Gallery{}}, delete_result)
    assert add_result in [{:error, :not_found}] or match?({:ok, %Gallery{}}, add_result)
    refute Repo.get(Gallery, gallery.id)

    refute Repo.exists?(
             from interaction in Interaction, where: interaction.gallery_id == ^gallery.id
           )
  end

  test "concurrent removals of the same image allow one removal" do
    user = confirmed_user_fixture()
    gallery = gallery_fixture(user)
    image = image_fixture()
    gallery_image_fixture(gallery, image)

    results =
      concurrently([
        fn -> Galleries.delete_gallery_image(actor(user), gallery.id, image.id) end,
        fn -> Galleries.delete_gallery_image(actor(user), gallery.id, image.id) end
      ])

    assert Enum.count(results, &match?({:ok, %Gallery{}}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :not_found})) == 1

    refute Repo.exists?(
             from interaction in Interaction, where: interaction.gallery_id == ^gallery.id
           )

    assert Repo.get!(Gallery, gallery.id).image_count == 0
  end

  test "removing an image concurrently with deleting its gallery is serialized" do
    user = confirmed_user_fixture()
    gallery = gallery_fixture(user)
    image = image_fixture()
    gallery_image_fixture(gallery, image)

    [remove_result, delete_result] =
      concurrently([
        fn -> Galleries.delete_gallery_image(actor(user), gallery.id, image.id) end,
        fn -> Galleries.delete_gallery(actor(user), gallery.id) end
      ])

    assert match?({:ok, %Gallery{}}, delete_result)
    assert remove_result == {:error, :not_found} or match?({:ok, %Gallery{}}, remove_result)
    refute Repo.get(Gallery, gallery.id)

    refute Repo.exists?(
             from interaction in Interaction, where: interaction.gallery_id == ^gallery.id
           )
  end

  test "concurrent additions assign strictly sequential ascending positions" do
    user = confirmed_user_fixture()
    gallery = gallery_fixture(user)
    images = Enum.map(1..8, fn _ -> image_fixture() end)

    results =
      concurrently(
        for image <- images do
          fn -> Galleries.create_gallery_image(actor(user), gallery.id, image.id) end
        end
      )

    assert Enum.all?(results, &match?({:ok, %Gallery{}}, &1))

    positions =
      Interaction
      |> where(gallery_id: ^gallery.id)
      |> order_by(:position)
      |> select([interaction], interaction.position)
      |> Repo.all()

    assert positions == Enum.to_list(0..(length(images) - 1))
    assert Repo.get!(Gallery, gallery.id).image_count == length(images)
  end

  test "concurrent gallery deletions allow one deletion" do
    user = confirmed_user_fixture()
    gallery = gallery_fixture(user)

    results =
      concurrently([
        fn -> Galleries.delete_gallery(actor(user), gallery.id) end,
        fn -> Galleries.delete_gallery(actor(user), gallery.id) end
      ])

    assert Enum.count(results, &match?({:ok, %Gallery{}}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :not_found})) == 1
    refute Repo.get(Gallery, gallery.id)
  end
end
