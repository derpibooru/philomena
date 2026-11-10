defmodule Philomena.GalleriesTest do
  @moduledoc """
  Context-level tests for the actor-first `Philomena.Galleries` functions.

  These pin the authorization matrices on the write paths (ban, missing
  fingerprint, owner vs unrelated user vs admin), the form loaders, the
  add/remove/reorder image operations, the read-mark and subscription
  helpers, and the search-backed page and index loaders.
  """

  use Philomena.DataCase, async: false

  @moduletag :search

  import Philomena.AttributionFixtures
  import Philomena.GalleriesFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures
  import Philomena.ReportsFixtures

  alias Philomena.Galleries
  alias Philomena.Galleries.Gallery
  alias Philomena.Galleries.GalleryPage
  alias Philomena.Galleries.Interaction
  alias Philomena.Galleries.ReorderForm
  alias Philomena.Images.Image
  alias Philomena.Images.Search.Scope
  alias Philomena.Repo
  alias Philomena.Reports.Report
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  # A truthy ban value in the shape production passes; only its presence
  # matters to the write-access and not-banned checks the loaders run first.
  @ban %{
    reason: "Rule #0",
    valid_until: ~U[3000-01-01 00:00:00Z],
    generated_ban_id: "U123456",
    type: "User"
  }

  @pagination %{page_number: 1, page_size: 25}

  setup do
    Search.clear_index!(Gallery)
    Search.clear_index!(Image)
    :ok
  end

  # The compiled filter body for a viewer with no active filter: it excludes
  # nothing.
  defp default_filter do
    %{
      bool: %{
        should: [
          %{terms: %{tag_ids: []}},
          %{bool: %{should: [%{match_none: %{}}, %{match_none: %{}}]}}
        ]
      }
    }
  end

  defp scope do
    Scope.new(default_filter(), @pagination)
  end

  describe "new_gallery/1" do
    test "an anonymous actor is unauthorized" do
      assert Galleries.new_gallery(actor(nil)) == {:error, :unauthorized}
    end

    test "a signed-in actor gets the new-gallery changeset" do
      assert {:ok, %Ecto.Changeset{}} = Galleries.new_gallery(actor(confirmed_user_fixture()))
    end

    test "a banned actor is rejected even while carrying a fingerprint" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Galleries.new_gallery(actor) == {:error, :ban}
    end

    test "an actor without a fingerprint still gets the form" do
      assert {:ok, %Ecto.Changeset{}} =
               Galleries.new_gallery(actor(confirmed_user_fixture(), fingerprint: nil))
    end
  end

  describe "create_gallery/2 with an actor" do
    test "a signed-in actor creates a gallery attributed to the user" do
      user = confirmed_user_fixture()
      thumbnail = image_fixture()

      assert {:ok, %Gallery{} = gallery} =
               Galleries.create_gallery(actor(user), %{
                 "title" => "A brand new gallery",
                 "thumbnail_id" => to_string(thumbnail.id)
               })

      assert gallery.user_id == user.id
      assert gallery.title == "A brand new gallery"
      assert Repo.get(Gallery, gallery.id)
    end

    test "a blank title is a rejected changeset" do
      thumbnail = image_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Galleries.create_gallery(actor(confirmed_user_fixture()), %{
                 "title" => "",
                 "thumbnail_id" => to_string(thumbnail.id)
               })

      refute changeset.valid?
      assert changeset.errors[:title]
    end

    test "a banned actor is rejected" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Galleries.create_gallery(actor, %{"title" => "x"}) == {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized" do
      actor = actor(confirmed_user_fixture(), fingerprint: nil)

      assert Galleries.create_gallery(actor, %{"title" => "x"}) == {:error, :unauthorized}
    end

    test "the ban wins over a missing fingerprint" do
      actor = actor(confirmed_user_fixture(), ban: @ban, fingerprint: nil)

      assert Galleries.create_gallery(actor, %{"title" => "x"}) == {:error, :ban}
    end
  end

  describe "update_gallery/3" do
    test "the owner updates their gallery" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)

      assert {:ok, %Gallery{}} =
               Galleries.update_gallery(actor(user), "#{gallery.id}", %{"title" => "Renamed"})

      assert Repo.reload!(gallery).title == "Renamed"
    end

    test "an admin updates another user's gallery" do
      gallery = gallery_fixture(confirmed_user_fixture())

      assert {:ok, %Gallery{}} =
               Galleries.update_gallery(actor(admin_user_fixture()), "#{gallery.id}", %{
                 "title" => "Admin renamed"
               })

      assert Repo.reload!(gallery).title == "Admin renamed"
    end

    test "an unrelated user is unauthorized and leaves the row unchanged" do
      gallery = gallery_fixture(confirmed_user_fixture())

      assert Galleries.update_gallery(actor(confirmed_user_fixture()), "#{gallery.id}", %{
               "title" => "Hijacked"
             }) == {:error, :unauthorized}

      assert Repo.reload!(gallery).title == gallery.title
    end

    test "a banned actor is rejected before any loading, even with a garbage id" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Galleries.update_gallery(actor, "abc", %{"title" => "x"}) == {:error, :ban}
    end

    test "an actor with no fingerprint is unauthorized" do
      gallery = gallery_fixture(confirmed_user_fixture())
      actor = actor(confirmed_user_fixture(), fingerprint: nil)

      assert Galleries.update_gallery(actor, "#{gallery.id}", %{"title" => "x"}) ==
               {:error, :unauthorized}
    end

    test "the ban wins over a missing fingerprint" do
      actor = actor(confirmed_user_fixture(), ban: @ban, fingerprint: nil)

      assert Galleries.update_gallery(actor, "abc", %{"title" => "x"}) == {:error, :ban}
    end

    test "a non-castable id is not-found" do
      assert Galleries.update_gallery(actor(confirmed_user_fixture()), "abc", %{"title" => "x"}) ==
               {:error, :not_found}
    end

    test "a well-formed id naming no row is not-found for every actor" do
      assert Galleries.update_gallery(actor(confirmed_user_fixture()), "999999999", %{
               "title" => "x"
             }) == {:error, :not_found}

      assert Galleries.update_gallery(actor(admin_user_fixture()), "999999999", %{"title" => "x"}) ==
               {:error, :not_found}
    end
  end

  describe "delete_gallery/2" do
    test "the owner deletes their gallery" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)

      assert {:ok, %Gallery{} = deleted} = Galleries.delete_gallery(actor(user), "#{gallery.id}")
      assert deleted.id == gallery.id
      assert Repo.reload(gallery) == nil
    end

    test "an unrelated user is unauthorized and leaves the row" do
      gallery = gallery_fixture(confirmed_user_fixture())

      assert Galleries.delete_gallery(actor(confirmed_user_fixture()), "#{gallery.id}") ==
               {:error, :unauthorized}

      refute Repo.reload(gallery) == nil
    end

    test "a banned actor is rejected even with a garbage id" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Galleries.delete_gallery(actor, "abc") == {:error, :ban}
    end

    test "a non-castable id is not-found" do
      assert Galleries.delete_gallery(actor(confirmed_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "a well-formed id naming no row is not-found for every actor" do
      assert Galleries.delete_gallery(actor(confirmed_user_fixture()), "999999999") ==
               {:error, :not_found}

      assert Galleries.delete_gallery(actor(admin_user_fixture()), "999999999") ==
               {:error, :not_found}
    end
  end

  describe "sequential gallery erasure" do
    test "deletes all owned galleries and closes their reports" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)
      other_gallery = gallery_fixture(user)
      report = report_fixture(gallery_id: gallery.id)
      admin = admin_user_fixture()

      assert report.open
      assert report.gallery_id == gallery.id

      assert {:ok, _deleted} = Galleries.delete_gallery(actor(admin), gallery.id)
      assert {:ok, _deleted} = Galleries.delete_gallery(actor(admin), other_gallery.id)

      closed = Repo.get!(Report, report.id)
      refute closed.open
      assert closed.state == "closed"
      assert closed.admin_id == admin.id
      # The FK is nilified by the database, orphaning the report as audit trail.
      assert closed.gallery_id == nil
      assert Enum.all?(Report.target_columns(), &is_nil(Map.get(closed, &1)))

      refute Repo.get(Philomena.Galleries.Gallery, gallery.id)
      refute Repo.get(Philomena.Galleries.Gallery, other_gallery.id)
    end
  end

  describe "edit_gallery/2" do
    test "the owner loads the gallery paired with its edit changeset, even without a fingerprint" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)

      assert {:ok, {%Gallery{} = loaded, %Ecto.Changeset{} = changeset}} =
               Galleries.edit_gallery(actor(user, fingerprint: nil), "#{gallery.id}")

      assert loaded.id == gallery.id
      assert changeset.data.id == gallery.id
    end

    test "an unrelated user is unauthorized" do
      gallery = gallery_fixture(confirmed_user_fixture())

      assert Galleries.edit_gallery(actor(confirmed_user_fixture()), "#{gallery.id}") ==
               {:error, :unauthorized}
    end

    test "a banned actor is rejected even while carrying a fingerprint" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Galleries.edit_gallery(actor, "abc") == {:error, :ban}
    end

    test "a non-castable id is not-found" do
      assert Galleries.edit_gallery(actor(confirmed_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "a well-formed id naming no row is not-found for every actor" do
      assert Galleries.edit_gallery(actor(confirmed_user_fixture()), "999999999") ==
               {:error, :not_found}

      assert Galleries.edit_gallery(actor(admin_user_fixture()), "999999999") ==
               {:error, :not_found}
    end
  end

  describe "create_gallery_image/3" do
    test "the owner adds an image at the last position" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)
      image = image_fixture()

      assert {:ok, %Gallery{} = result} =
               Galleries.create_gallery_image(actor(user), "#{gallery.id}", "#{image.id}")

      assert %Gallery{} = result
      assert result.image_count == 1
      assert Repo.reload!(gallery).image_count == 1
    end

    test "an unrelated user is unauthorized" do
      gallery = gallery_fixture(confirmed_user_fixture())
      image = image_fixture()

      assert Galleries.create_gallery_image(
               actor(confirmed_user_fixture()),
               "#{gallery.id}",
               "#{image.id}"
             ) == {:error, :unauthorized}
    end

    test "malformed and missing image ids are not-found" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)

      assert Galleries.create_gallery_image(actor(user), gallery.id, "abc") ==
               {:error, :not_found}

      assert Galleries.create_gallery_image(actor(user), gallery.id, "999999999") ==
               {:error, :not_found}
    end

    test "a hidden image is unauthorized for an ordinary owner" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)
      image = image_fixture(hidden_from_users: true)

      assert Galleries.create_gallery_image(actor(user), gallery.id, image.id) ==
               {:error, :unauthorized}

      assert Repo.aggregate(Interaction, :count) == 0
    end

    test "a banned actor is rejected" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Galleries.create_gallery_image(actor, "abc", "abc") == {:error, :ban}
    end

    test "adding an image already in the gallery returns a changeset error" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)
      image = image_fixture()

      {:ok, _} = Galleries.create_gallery_image(actor(user), "#{gallery.id}", "#{image.id}")

      assert {:error, %Ecto.Changeset{} = changeset} =
               Galleries.create_gallery_image(actor(user), "#{gallery.id}", "#{image.id}")

      assert changeset.errors[:interactions]
      assert Repo.reload!(gallery).image_count == 1
      assert Repo.aggregate(Interaction, :count) == 1
    end
  end

  describe "delete_gallery_image/3" do
    test "the owner removes an image in the gallery" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)
      image = image_fixture()

      {:ok, _} = Galleries.create_gallery_image(actor(user), "#{gallery.id}", "#{image.id}")

      assert {:ok, result} =
               Galleries.delete_gallery_image(actor(user), "#{gallery.id}", "#{image.id}")

      assert result.image_count == 0
      assert Repo.reload!(gallery).image_count == 0
    end

    test "removing an image not in the gallery returns not-found" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)
      image = image_fixture()

      assert Galleries.delete_gallery_image(actor(user), "#{gallery.id}", "#{image.id}") ==
               {:error, :not_found}
    end

    test "an unrelated user is unauthorized" do
      gallery = gallery_fixture(confirmed_user_fixture())
      image = image_fixture()

      assert Galleries.delete_gallery_image(
               actor(confirmed_user_fixture()),
               "#{gallery.id}",
               "#{image.id}"
             ) == {:error, :unauthorized}
    end
  end

  describe "update_gallery_order/3" do
    test "the owner reorders synchronously and gets the reorder form back" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)
      images = [image_fixture(), image_fixture(), image_fixture()]
      Enum.each(images, &gallery_image_fixture(gallery, &1))

      requested_ids = Enum.map(images, & &1.id)

      assert {:ok, %ReorderForm{} = returned} =
               Galleries.update_gallery_order(
                 actor(user),
                 "#{gallery.id}",
                 %{image_ids: requested_ids}
               )

      assert returned.gallery.id == gallery.id
      assert returned.image_ids == requested_ids

      assert %{position: 2} =
               Repo.get_by!(Interaction, gallery_id: gallery.id, image_id: Enum.at(images, 0).id)

      assert %{position: 1} =
               Repo.get_by!(Interaction, gallery_id: gallery.id, image_id: Enum.at(images, 1).id)

      assert %{position: 0} =
               Repo.get_by!(Interaction, gallery_id: gallery.id, image_id: Enum.at(images, 2).id)
    end

    test "an unrelated user is unauthorized" do
      gallery = gallery_fixture(confirmed_user_fixture())
      image_a = image_fixture()
      image_b = image_fixture()

      assert Galleries.update_gallery_order(actor(confirmed_user_fixture()), "#{gallery.id}", %{
               "image_ids" => [image_a.id, image_b.id]
             }) ==
               {:error, :unauthorized}
    end

    test "a banned actor is rejected" do
      actor = actor(confirmed_user_fixture(), ban: @ban)

      assert Galleries.update_gallery_order(actor, "abc", [1]) == {:error, :ban}
    end

    test "accepts a subset but rejects extra, duplicate, and malformed image ids" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)
      [image_a, image_b] = [image_fixture(), image_fixture()]
      gallery_image_fixture(gallery, image_a)
      gallery_image_fixture(gallery, image_b)

      assert {:ok, %ReorderForm{}} =
               Galleries.update_gallery_order(actor(user), gallery.id, %{
                 "image_ids" => [image_a.id]
               })

      for invalid_order <- [
            [image_a.id, image_b.id, 999_999_999],
            [image_a.id, image_a.id],
            [to_string(image_a.id), "not-an-id"]
          ] do
        assert {:error, %Ecto.Changeset{}} =
                 Galleries.update_gallery_order(actor(user), gallery.id, %{
                   "image_ids" => invalid_order
                 })
      end
    end

    test "accepts string ids in a subset" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)
      [image_a, image_b] = [image_fixture(), image_fixture()]
      gallery_image_fixture(gallery, image_a)
      gallery_image_fixture(gallery, image_b)

      assert {:ok, %ReorderForm{}} =
               Galleries.update_gallery_order(actor(user), gallery.id, %{
                 "image_ids" => [to_string(image_b.id)]
               })
    end
  end

  describe "ReorderForm" do
    test "casts decimal string image ids to integers" do
      changeset = ReorderForm.changeset(%ReorderForm{}, %{"image_ids" => ["12", "34"]})

      assert {:ok, %ReorderForm{image_ids: [12, 34]}} =
               Ecto.Changeset.apply_action(changeset, :create)
    end

    test "rejects duplicate image ids" do
      changeset = ReorderForm.changeset(%ReorderForm{}, %{image_ids: [12, 12]})

      refute changeset.valid?
      assert changeset.errors[:image_ids]
    end

    test "rejects malformed image ids" do
      changeset = ReorderForm.changeset(%ReorderForm{}, %{image_ids: [12, "not-an-id"]})

      refute changeset.valid?
      assert changeset.errors[:image_ids]
    end
  end

  describe "create_gallery_read/2" do
    test "a known gallery is marked read for the user" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(confirmed_user_fixture())

      assert {:ok, %Gallery{} = returned} =
               Galleries.create_gallery_read(actor(user), "#{gallery.id}")

      assert returned.id == gallery.id
    end

    # No authorization runs here, so an unknown id is not-found for everyone,
    # admins included.
    test "an unknown id is not-found for a user and for an admin" do
      assert Galleries.create_gallery_read(actor(confirmed_user_fixture()), "999999999") ==
               {:error, :not_found}

      assert Galleries.create_gallery_read(actor(admin_user_fixture()), "999999999") ==
               {:error, :not_found}
    end

    test "a non-castable id is not-found" do
      assert Galleries.create_gallery_read(actor(confirmed_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "an anonymous actor is unauthorized for a real gallery" do
      gallery = gallery_fixture(confirmed_user_fixture())

      assert Galleries.create_gallery_read(actor(), gallery.id) == {:error, :unauthorized}
    end
  end

  describe "create_gallery_subscription/2 and delete_gallery_subscription/2" do
    test "subscribing then unsubscribing toggles the subscription" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(confirmed_user_fixture())

      assert {:ok, %Gallery{}} =
               Galleries.create_gallery_subscription(actor(user), "#{gallery.id}")

      assert Galleries.subscribed?(gallery, user)

      assert {:ok, %Gallery{}} =
               Galleries.delete_gallery_subscription(actor(user), "#{gallery.id}")

      refute Galleries.subscribed?(gallery, user)
    end

    test "unsubscribing when not subscribed is an idempotent success" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(confirmed_user_fixture())

      assert {:ok, %Gallery{}} =
               Galleries.delete_gallery_subscription(actor(user), "#{gallery.id}")

      refute Galleries.subscribed?(gallery, user)
    end

    test "subscribing to an unknown id is not-found" do
      assert Galleries.create_gallery_subscription(actor(confirmed_user_fixture()), "999999999") ==
               {:error, :not_found}
    end

    test "a non-castable id is not-found" do
      assert Galleries.create_gallery_subscription(actor(confirmed_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "a banned actor can subscribe or unsubscribe" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(confirmed_user_fixture())
      actor = actor(user, ban: @ban)

      assert {:ok, %Gallery{}} = Galleries.create_gallery_subscription(actor, "#{gallery.id}")
      assert Galleries.subscribed?(gallery, user)

      assert {:ok, %Gallery{}} = Galleries.delete_gallery_subscription(actor, "#{gallery.id}")
      refute Galleries.subscribed?(gallery, user)
    end
  end

  describe "show_gallery/2" do
    test "the owner's scope gets a gallery page containing the gallery's image" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)
      image = image_fixture()

      gallery_image_fixture(gallery, image)
      SearchHelpers.reindex_all!(Image)

      assert {:ok, %GalleryPage{} = page} =
               Galleries.show_gallery(actor(user), scope(), "#{gallery.id}")

      assert page.gallery.id == gallery.id
      # The images page carries {image, hit} tuples, not bare image structs.
      assert image.id in Enum.map(page.images, fn {img, _hit} -> img.id end)
      assert is_boolean(page.watching)
      assert is_boolean(page.gallery_prev)
      assert is_boolean(page.gallery_next)
      assert is_list(page.interactions)
    end

    test "the images flanking a page are the ones just before and after it" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)

      for image <- [image_fixture(), image_fixture(), image_fixture()] do
        gallery_image_fixture(gallery, image)
      end

      SearchHelpers.reindex_all!(Image)

      page_ids = fn page_number ->
        page_scope = Scope.new(default_filter(), %{page_number: page_number, page_size: 1})
        {:ok, page} = Galleries.show_gallery(actor(user), page_scope, "#{gallery.id}")
        {page, Enum.map(page.images, fn {image, _hit} -> image.id end)}
      end

      {_page, [first]} = page_ids.(1)
      {middle_page, [middle]} = page_ids.(2)
      {_page, [last]} = page_ids.(3)

      assert Enum.map(middle_page.gallery_images, fn {image, _hit} -> image.id end) ==
               [first, middle, last]
    end

    test "an anonymous viewer sees an empty gallery's page" do
      gallery = gallery_fixture(confirmed_user_fixture())
      SearchHelpers.reindex_all!(Image)

      assert {:ok, %GalleryPage{} = page} =
               Galleries.show_gallery(actor(), scope(), "#{gallery.id}")

      assert page.gallery.id == gallery.id
      assert Enum.empty?(page.images)
    end

    test "an unknown id is not-found for an anonymous viewer" do
      assert Galleries.show_gallery(actor(), scope(), "999999999") ==
               {:error, :not_found}
    end

    test "a non-castable id is not-found" do
      assert Galleries.show_gallery(actor(), scope(), "abc") == {:error, :not_found}
    end
  end

  describe "list_galleries/3" do
    test "a title filter finds a matching gallery and excludes others" do
      user = confirmed_user_fixture()
      wanted = gallery_fixture(user, title: "Test Wanted Gallery")
      other = gallery_fixture(user, title: "Test Unrelated Gallery")
      SearchHelpers.reindex_all!(Gallery)

      assert {:ok, page, _changeset} =
               Galleries.list_galleries(
                 actor(),
                 %{"title" => "wanted"},
                 @pagination
               )

      ids = Enum.map(page.entries, & &1.id)
      assert wanted.id in ids
      refute other.id in ids
    end

    test "no filter returns the gallery with its thumbnail preloaded" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)
      SearchHelpers.reindex_all!(Gallery)

      assert {:ok, page, _changeset} = Galleries.list_galleries(actor(), %{}, @pagination)

      assert [%Gallery{} = loaded] = Enum.filter(page.entries, &(&1.id == gallery.id))
      # The thumbnail association is loaded, not left as a lazy placeholder.
      refute match?(%Ecto.Association.NotLoaded{}, loaded.thumbnail)
    end

    test "membership changes are reflected when the gallery worker reindexes" do
      user = confirmed_user_fixture()
      gallery = gallery_fixture(user)
      image = image_fixture()
      gallery_image_fixture(gallery, image)

      assert :ok = Galleries.perform_reindex(:id, [gallery.id])
      :ok = Search.refresh_index!(Gallery)

      params = %{"include_image" => to_string(image.id)}
      assert {:ok, page, _changeset} = Galleries.list_galleries(actor(), params, @pagination)
      assert Enum.any?(page.entries, &(&1.id == gallery.id))

      assert {:ok, _gallery} =
               Galleries.delete_gallery_image(actor(user), gallery.id, image.id)

      assert :ok = Galleries.perform_reindex(:id, [gallery.id])
      :ok = Search.refresh_index!(Gallery)
      assert {:ok, page, _changeset} = Galleries.list_galleries(actor(), params, @pagination)
      refute Enum.any?(page.entries, &(&1.id == gallery.id))
    end
  end

  describe "query_galleries/3" do
    test "finds galleries by thumbnail and spoiler warning" do
      user = confirmed_user_fixture()
      thumbnail = image_fixture()
      wanted = gallery_fixture(user, thumbnail_id: thumbnail.id, spoiler_warning: "grapefruit")
      _other = gallery_fixture(user)
      SearchHelpers.reindex_all!(Gallery)

      for query <- ["thumbnail_id:#{thumbnail.id}", "spoiler_warning:grapefruit"] do
        assert {:ok, %{entries: [%Gallery{id: id}]}} =
                 Galleries.query_galleries(actor(), query, @pagination)

        assert id == wanted.id
      end
    end
  end

  describe "gallery_choices_for_image/2" do
    test "returns no choices for an anonymous actor" do
      assert Galleries.gallery_choices_for_image(actor(), image_fixture()) == {:ok, []}
    end

    test "limits the signed-in actor's selector to 100 galleries" do
      user = confirmed_user_fixture()
      thumbnail = image_fixture()
      now = DateTime.utc_now(:second)

      rows =
        Enum.map(1..101, fn number ->
          %{
            user_id: user.id,
            thumbnail_id: thumbnail.id,
            title: "Selector gallery #{number}",
            description: "",
            spoiler_warning: "",
            anonymous: false,
            image_count: 0,
            order_position_asc: false,
            created_at: now,
            updated_at: DateTime.add(now, number, :second)
          }
        end)

      {101, nil} = Repo.insert_all(Gallery, rows)

      assert {:ok, choices} = Galleries.gallery_choices_for_image(actor(user), thumbnail)
      assert length(choices) == 100
    end
  end
end
