defmodule Philomena.StaticPagesTest do
  @moduledoc """
  Context-level tests for the controller-facing `Philomena.StaticPages`
  functions.

  These pin the staff-only index gate, missing-first public show/history
  loaders, write-access parity, action authorization, atomic revisions, and
  changeset failures.
  """

  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1, actor: 2]
  import Philomena.StaticPagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo
  alias Philomena.StaticPages
  alias Philomena.StaticPages.StaticPage

  describe "upsert_statistics_page/1" do
    test "creates and replaces the generated statistics page" do
      assert {1, nil} = StaticPages.upsert_statistics_page("first snapshot")
      assert Repo.get_by!(StaticPage, slug: "stats").body == "first snapshot"

      assert {1, nil} = StaticPages.upsert_statistics_page("second snapshot")

      page = Repo.get_by!(StaticPage, slug: "stats")
      assert page.title == "Statistics"
      assert page.body == "second snapshot"
      assert Repo.aggregate(StaticPage, :count, :id) == 1
    end
  end

  describe "list_pages/1" do
    test "an admin gets the list of static pages" do
      page = static_page_fixture(admin_user_fixture())

      assert {:ok, pages} = StaticPages.list_pages(actor(admin_user_fixture()))
      assert page.id in Enum.map(pages, & &1.id)
    end

    test "a moderator with the StaticPage admin grant may list them" do
      moderator = role_moderator_fixture("StaticPage")

      assert {:ok, _pages} = StaticPages.list_pages(actor(moderator))
    end

    test "a regular user is unauthorized" do
      assert StaticPages.list_pages(actor(confirmed_user_fixture())) ==
               {:error, :unauthorized}
    end

    test "an anonymous viewer is unauthorized" do
      assert StaticPages.list_pages(actor()) == {:error, :unauthorized}
    end
  end

  describe "show_page/2" do
    test "an anonymous viewer loads a page by slug" do
      page = static_page_fixture(admin_user_fixture())

      assert {:ok, loaded} = StaticPages.show_page(actor(), page.slug)
      assert loaded.id == page.id
    end

    test "an unknown slug is not-found for every actor" do
      assert StaticPages.show_page(actor(confirmed_user_fixture()), "no-such-page") ==
               {:error, :not_found}

      assert StaticPages.show_page(actor(admin_user_fixture()), "no-such-page") ==
               {:error, :not_found}
    end
  end

  describe "list_page_history/2" do
    test "an anonymous viewer loads newest-first revision history" do
      admin = admin_user_fixture()
      page = static_page_fixture(admin, %{body: "First"})

      assert {:ok, _updated} =
               StaticPages.update_page(actor(admin), page.slug, %{
                 title: page.title,
                 slug: page.slug,
                 body: "Second"
               })

      assert {:ok, {%StaticPage{id: page_id}, [latest, initial]}} =
               StaticPages.list_page_history(actor(), page.slug)

      assert page_id == page.id
      assert latest.body == "Second"
      assert initial.body == "First"
    end

    test "an unknown slug is not-found" do
      assert StaticPages.list_page_history(actor(), "no-such-page") == {:error, :not_found}
    end
  end

  describe "new_page/1" do
    test "an admin gets a blank changeset" do
      assert {:ok, %Ecto.Changeset{data: %StaticPage{}}} =
               StaticPages.new_page(actor(admin_user_fixture()))
    end

    test "a regular user is unauthorized" do
      assert StaticPages.new_page(actor(confirmed_user_fixture())) == {:error, :unauthorized}
    end

    test "a ban is refused but a missing fingerprint is not" do
      admin = admin_user_fixture()

      assert StaticPages.new_page(actor(admin, ban: %{})) == {:error, :ban}
      assert {:ok, %Ecto.Changeset{}} = StaticPages.new_page(actor(admin, fingerprint: nil))
    end
  end

  describe "create_page/2" do
    test "an admin creates a page and its initial version" do
      slug = unique_static_page_slug()

      assert {:ok, %StaticPage{} = page} =
               StaticPages.create_page(actor(admin_user_fixture()), %{
                 "title" => "Created Page",
                 "slug" => slug,
                 "body" => "Body text"
               })

      assert page.slug == slug
    end

    test "invalid attrs return the page changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               StaticPages.create_page(actor(admin_user_fixture()), %{"title" => ""})

      refute changeset.valid?
    end

    test "a regular user is unauthorized" do
      assert StaticPages.create_page(actor(confirmed_user_fixture()), %{
               "title" => "x",
               "slug" => "y",
               "body" => "z"
             }) == {:error, :unauthorized}
    end

    test "write-access failures precede authorization" do
      admin = admin_user_fixture()

      assert StaticPages.create_page(actor(admin, ban: %{}), %{}) == {:error, :ban}
    end
  end

  describe "edit_page/2" do
    test "an admin loads a page and a changeset" do
      page = static_page_fixture(admin_user_fixture())

      assert {:ok, {%StaticPage{} = loaded, %Ecto.Changeset{}}} =
               StaticPages.edit_page(actor(admin_user_fixture()), page.slug)

      assert loaded.id == page.id
    end

    test "a regular user is unauthorized" do
      page = static_page_fixture(admin_user_fixture())

      assert StaticPages.edit_page(actor(confirmed_user_fixture()), page.slug) ==
               {:error, :unauthorized}
    end

    test "write-access failures match update" do
      admin = admin_user_fixture()
      page = static_page_fixture(admin)

      assert StaticPages.edit_page(actor(admin, ban: %{}), page.slug) ==
               {:error, :ban}
    end
  end

  describe "update_page/3" do
    test "an admin updates a page and stores a new version" do
      admin = admin_user_fixture()
      page = static_page_fixture(admin)

      # The new Version row requires the full page fields, not just the changed
      # one, so the update carries slug and body alongside the new title.
      assert {:ok, %StaticPage{} = updated} =
               StaticPages.update_page(actor(admin), page.slug, %{
                 "title" => "Updated Title",
                 "slug" => page.slug,
                 "body" => "Updated body"
               })

      assert updated.title == "Updated Title"
      assert Repo.get!(StaticPage, page.id).title == "Updated Title"
    end

    test "an invalid update returns the page changeset" do
      admin = admin_user_fixture()
      page = static_page_fixture(admin)

      assert {:error, %Ecto.Changeset{} = changeset} =
               StaticPages.update_page(actor(admin), page.slug, %{"title" => ""})

      refute changeset.valid?
      assert Repo.get!(StaticPage, page.id).title == page.title
    end

    test "an unknown slug is not-found for every actor with write access" do
      assert StaticPages.update_page(actor(confirmed_user_fixture()), "no-such-page", %{
               "title" => "x"
             }) ==
               {:error, :not_found}

      assert StaticPages.update_page(actor(admin_user_fixture()), "no-such-page", %{
               "title" => "x"
             }) ==
               {:error, :not_found}
    end

    test "write-access failures precede loading" do
      admin = admin_user_fixture()

      assert StaticPages.update_page(actor(admin, ban: %{}), "no-such-page", %{}) ==
               {:error, :ban}
    end

    test "a regular user is unauthorized" do
      page = static_page_fixture(admin_user_fixture())

      assert StaticPages.update_page(actor(confirmed_user_fixture()), page.slug, %{
               "title" => "Hijacked"
             }) ==
               {:error, :unauthorized}
    end
  end
end
