defmodule Philomena.SiteNoticesTest do
  @moduledoc """
  Context-level tests for the admin site-notice management functions on
  `Philomena.SiteNotices`: `load_site_notices/2`, `new_site_notice/1`,
  `create_site_notice/2`, `load_site_notice_for_edit/2`, `update_site_notice/3`,
  and `delete_site_notice/2`.

  These pin the per-role authorization matrix (admin and a moderator holding the
  SiteNotice admin grant pass; a plain moderator, a regular user, and an
  anonymous visitor are rejected), the write prerequisite, and the shared
  loader contract: malformed and absent IDs are not found for every actor,
  while a real forbidden notice is unauthorized. No moderation logs are written
  here.

  The actor is a `Philomena.Attribution.Actor`, matching what the controller
  hands in as `conn.assigns.actor`.
  """

  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1, actor: 2]
  import Philomena.SiteNoticesFixtures
  import Philomena.UsersFixtures

  alias Philomena.SiteNotices
  alias Philomena.SiteNotices.SiteNotice

  @pagination %{page_number: 1, page_size: 25}
  @ban %{reason: "Rule #0", valid_until: ~U[3000-01-01 00:00:00Z]}

  # A moderator granted the SiteNotice admin role_map, the shape a request-loaded
  # actor carries; site-notice management admits this moderator but not a plain
  # one.
  defp notice_moderator do
    %{moderator_user_fixture() | role_map: %{"SiteNotice" => %{"admin" => []}}}
  end

  # Controller-shaped attrs (string keys) a site-notice insert requires;
  # start_date/finish_date are RelativeDate fields a plain DateTime casts fine.
  defp valid_attrs do
    %{
      "title" => "Scheduled maintenance",
      "text" => "The site will be down.",
      "start_date" => DateTime.utc_now(:second),
      "finish_date" => DateTime.add(DateTime.utc_now(:second), 365, :day)
    }
  end

  describe "active_site_notices/0" do
    test "returns only live notices inside their active UTC window" do
      now = DateTime.utc_now(:second)
      active = site_notice_fixture(%{"start_date" => DateTime.add(now, -1, :day)})
      _not_live = site_notice_fixture(%{"live" => false})

      _not_started =
        site_notice_fixture(%{
          "start_date" => DateTime.add(now, 1, :day),
          "finish_date" => DateTime.add(now, 2, :day)
        })

      _finished =
        site_notice_fixture(%{
          "start_date" => DateTime.add(now, -2, :day),
          "finish_date" => DateTime.add(now, -1, :day)
        })

      assert Enum.map(SiteNotices.active_site_notices(), & &1.id) == [active.id]
    end
  end

  describe "list_site_notices/2" do
    test "an admin gets the paginated site notices" do
      admin = admin_user_fixture()
      notice = site_notice_fixture()

      assert {:ok, page} = SiteNotices.list_site_notices(actor(admin), @pagination)
      assert %Scrivener.Page{} = page
      assert notice.id in Enum.map(page.entries, & &1.id)
    end

    test "a moderator with the site-notice grant is authorized" do
      notice = site_notice_fixture()

      assert {:ok, page} = SiteNotices.list_site_notices(actor(notice_moderator()), @pagination)
      assert notice.id in Enum.map(page.entries, & &1.id)
    end

    test "a plain moderator is not authorized" do
      assert SiteNotices.list_site_notices(actor(moderator_user_fixture()), @pagination) ==
               {:error, :unauthorized}
    end

    test "a regular user is not authorized" do
      assert SiteNotices.list_site_notices(actor(confirmed_user_fixture()), @pagination) ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      assert SiteNotices.list_site_notices(actor(), @pagination) == {:error, :unauthorized}
    end
  end

  describe "new_site_notice/1" do
    test "an admin gets a changeset" do
      assert {:ok, %Ecto.Changeset{}} = SiteNotices.new_site_notice(actor(admin_user_fixture()))
    end

    test "a moderator with the site-notice grant is authorized" do
      assert {:ok, %Ecto.Changeset{}} = SiteNotices.new_site_notice(actor(notice_moderator()))
    end

    test "a plain moderator is not authorized" do
      assert SiteNotices.new_site_notice(actor(moderator_user_fixture())) ==
               {:error, :unauthorized}
    end

    test "a regular user is not authorized" do
      assert SiteNotices.new_site_notice(actor(confirmed_user_fixture())) ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      assert SiteNotices.new_site_notice(actor()) == {:error, :unauthorized}
    end
  end

  describe "create_site_notice/2" do
    test "an admin creates a notice authored by them" do
      admin = admin_user_fixture()

      assert {:ok, %SiteNotice{} = notice} =
               SiteNotices.create_site_notice(actor(admin), valid_attrs())

      assert notice.user_id == admin.id
    end

    test "a moderator with the site-notice grant creates a notice" do
      moderator = notice_moderator()

      assert {:ok, %SiteNotice{} = notice} =
               SiteNotices.create_site_notice(actor(moderator), valid_attrs())

      assert notice.user_id == moderator.id
    end

    test "invalid attributes return a changeset" do
      assert {:error, %Ecto.Changeset{}} =
               SiteNotices.create_site_notice(actor(admin_user_fixture()), %{
                 valid_attrs()
                 | "title" => ""
               })
    end

    test "a plain moderator is not authorized and creates nothing" do
      assert SiteNotices.create_site_notice(actor(moderator_user_fixture()), valid_attrs()) ==
               {:error, :unauthorized}
    end

    test "a regular user is not authorized" do
      assert SiteNotices.create_site_notice(actor(confirmed_user_fixture()), valid_attrs()) ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      assert SiteNotices.create_site_notice(actor(), valid_attrs()) == {:error, :unauthorized}
    end
  end

  describe "edit_site_notice/2" do
    test "an admin loads the notice with a changeset" do
      admin = admin_user_fixture()
      notice = site_notice_fixture()

      assert {:ok, {loaded, %Ecto.Changeset{}}} =
               SiteNotices.edit_site_notice(actor(admin), notice.id)

      assert loaded.id == notice.id
    end

    test "a moderator with the site-notice grant loads the notice" do
      notice = site_notice_fixture()

      assert {:ok, {loaded, _}} =
               SiteNotices.edit_site_notice(actor(notice_moderator()), notice.id)

      assert loaded.id == notice.id
    end

    test "a well-formed unknown id is not found for an admin" do
      assert SiteNotices.edit_site_notice(actor(admin_user_fixture()), 2_147_483_647) ==
               {:error, :not_found}
    end

    test "a well-formed unknown id is not found for a plain moderator" do
      assert SiteNotices.edit_site_notice(actor(moderator_user_fixture()), 2_147_483_647) ==
               {:error, :not_found}
    end

    test "a well-formed unknown id is not found for a regular user" do
      assert SiteNotices.edit_site_notice(actor(confirmed_user_fixture()), 2_147_483_647) ==
               {:error, :not_found}
    end

    test "a non-castable id is not found for an admin" do
      assert SiteNotices.edit_site_notice(actor(admin_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "a non-castable id is not found for a plain moderator" do
      # The id parse fails before authorization runs, so a non-castable id is
      # not_found even for an actor who could never see the record.
      assert SiteNotices.edit_site_notice(actor(moderator_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "a real notice is unauthorized for a plain moderator" do
      notice = site_notice_fixture()

      assert SiteNotices.edit_site_notice(actor(moderator_user_fixture()), notice.id) ==
               {:error, :unauthorized}
    end

    test "a real notice is unauthorized for a regular user" do
      notice = site_notice_fixture()

      assert SiteNotices.edit_site_notice(actor(confirmed_user_fixture()), notice.id) ==
               {:error, :unauthorized}
    end
  end

  describe "update_site_notice/3" do
    test "an admin updates the notice" do
      notice = site_notice_fixture()

      assert {:ok, updated} =
               SiteNotices.update_site_notice(actor(admin_user_fixture()), notice.id, %{
                 "title" => "Rescheduled"
               })

      assert updated.title == "Rescheduled"
    end

    test "a moderator with the site-notice grant updates the notice" do
      notice = site_notice_fixture()

      assert {:ok, _} =
               SiteNotices.update_site_notice(actor(notice_moderator()), notice.id, %{
                 "title" => "x"
               })
    end

    test "invalid attributes return a changeset" do
      notice = site_notice_fixture()

      assert {:error, %Ecto.Changeset{}} =
               SiteNotices.update_site_notice(actor(admin_user_fixture()), notice.id, %{
                 "title" => ""
               })
    end

    test "a well-formed unknown id is not found for an admin" do
      assert SiteNotices.update_site_notice(actor(admin_user_fixture()), 2_147_483_647, %{
               "title" => "x"
             }) ==
               {:error, :not_found}
    end

    test "a well-formed unknown id is not found for a plain moderator" do
      assert SiteNotices.update_site_notice(actor(moderator_user_fixture()), 2_147_483_647, %{
               "title" => "x"
             }) == {:error, :not_found}
    end

    test "a real notice is unauthorized for a plain moderator" do
      notice = site_notice_fixture()

      assert SiteNotices.update_site_notice(actor(moderator_user_fixture()), notice.id, %{
               "title" => "x"
             }) ==
               {:error, :unauthorized}
    end

    test "a regular user is not authorized" do
      notice = site_notice_fixture()

      assert SiteNotices.update_site_notice(actor(confirmed_user_fixture()), notice.id, %{
               "title" => "x"
             }) ==
               {:error, :unauthorized}
    end
  end

  describe "delete_site_notice/2" do
    test "an admin deletes the notice" do
      notice = site_notice_fixture()

      assert {:ok, deleted} =
               SiteNotices.delete_site_notice(actor(admin_user_fixture()), notice.id)

      assert deleted.id == notice.id
      refute Repo.get(SiteNotice, notice.id)
    end

    test "a moderator with the site-notice grant deletes the notice" do
      notice = site_notice_fixture()

      assert {:ok, _} = SiteNotices.delete_site_notice(actor(notice_moderator()), notice.id)
      refute Repo.get(SiteNotice, notice.id)
    end

    test "a well-formed unknown id is not found for an admin" do
      assert SiteNotices.delete_site_notice(actor(admin_user_fixture()), 2_147_483_647) ==
               {:error, :not_found}
    end

    test "a well-formed unknown id is not found for a plain moderator" do
      assert SiteNotices.delete_site_notice(actor(moderator_user_fixture()), 2_147_483_647) ==
               {:error, :not_found}
    end

    test "a non-castable id is not found for an admin" do
      assert SiteNotices.delete_site_notice(actor(admin_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "a real notice is unauthorized for a plain moderator" do
      notice = site_notice_fixture()

      assert SiteNotices.delete_site_notice(actor(moderator_user_fixture()), notice.id) ==
               {:error, :unauthorized}

      assert Repo.get(SiteNotice, notice.id)
    end

    test "a regular user is not authorized" do
      notice = site_notice_fixture()

      assert SiteNotices.delete_site_notice(actor(confirmed_user_fixture()), notice.id) ==
               {:error, :unauthorized}
    end

    test "an anonymous visitor is not authorized" do
      notice = site_notice_fixture()
      assert SiteNotices.delete_site_notice(actor(), notice.id) == {:error, :unauthorized}
    end
  end

  describe "write access prerequisite" do
    test "forms reject bans but not missing fingerprints" do
      admin = admin_user_fixture()
      notice = site_notice_fixture()

      for operation <- [
            &SiteNotices.new_site_notice/1,
            &SiteNotices.edit_site_notice(&1, notice.id)
          ] do
        assert operation.(actor(admin, ban: @ban)) == {:error, :ban}
        assert {:ok, _} = operation.(actor(admin, fingerprint: nil))
      end
    end

    test "mutations reject bans and missing fingerprints" do
      admin = admin_user_fixture()
      notice = site_notice_fixture()

      operations = [
        &SiteNotices.create_site_notice(&1, valid_attrs()),
        &SiteNotices.update_site_notice(&1, notice.id, %{"title" => "Changed"}),
        &SiteNotices.delete_site_notice(&1, notice.id)
      ]

      for operation <- operations do
        assert operation.(actor(admin, ban: @ban)) == {:error, :ban}
        assert operation.(actor(admin, fingerprint: nil)) == {:error, :unauthorized}
      end
    end
  end
end
