defmodule Philomena.BadgesTest do
  @moduledoc """
  Context-level tests for the actor-first badge-award loaders and writers on
  `Philomena.Badges`.

  Awarding is admin/moderator-only (the `:create` permission on `Award`); these
  pin that matrix, the not-found shapes for unknown slugs and award ids, and the
  byte-exact moderation logs each write emits (type, body, and subject path),
  including that failure and authorization paths write none.
  """

  use Philomena.DataCase, async: true

  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1, actor: 2]
  import Philomena.BadgesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Badges
  alias Philomena.Badges.Award
  alias Philomena.Badges.Badge
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.Repo

  @pagination %{page_number: 1, page_size: 25}
  @ban %{reason: "Rule #0", valid_until: ~U[3000-01-01 00:00:00Z]}

  # A profile user with an all-unreserved slug, so the moderation-log
  # subject_path is byte-identical to "/profiles/<slug>" with no percent-encoding.
  defp awardee_fixture do
    confirmed_user_fixture(%{name: "awardee#{System.unique_integer([:positive])}"})
  end

  defp moderation_logs, do: Repo.all(ModerationLog)

  defp no_moderation_logs! do
    assert Repo.aggregate(ModerationLog, :count) == 0
  end

  describe "new_award/2" do
    test "returns enabled badges ordered by title and excludes disabled ones" do
      beta = badge_fixture(%{title: "Beta Badge"})
      alpha = badge_fixture(%{title: "Alpha Badge"})
      _disabled = badge_fixture(%{title: "Gamma Badge", disable_award: true})
      user = awardee_fixture()

      assert {:ok, {_user, _changeset, badges}} =
               Badges.new_award(actor(admin_user_fixture()), user.slug)

      titles = Enum.map(badges, & &1.title)

      # Ordered ascending by title, and the disabled badge is absent.
      assert Enum.find_index(titles, &(&1 == alpha.title)) <
               Enum.find_index(titles, &(&1 == beta.title))

      refute "Gamma Badge" in titles
    end

    test "an admin gets the profile user and a changeset" do
      user = awardee_fixture()

      assert {:ok, {loaded_user, %Ecto.Changeset{data: %Award{}}, badges}} =
               Badges.new_award(actor(admin_user_fixture()), user.slug)

      assert loaded_user.id == user.id
      assert is_list(badges)
    end

    test "a regular user may not award badges" do
      user = awardee_fixture()

      assert Badges.new_award(actor(confirmed_user_fixture()), user.slug) ==
               {:error, :unauthorized}
    end

    test "a permitted actor naming an unknown slug is not-found" do
      assert Badges.new_award(actor(admin_user_fixture()), "no-such-user") ==
               {:error, :not_found}
    end
  end

  describe "create_award/3" do
    test "an admin awards a badge, inserting the award and a byte-exact create log" do
      admin = admin_user_fixture()
      user = awardee_fixture()
      badge = badge_fixture(%{title: "Test Award Badge"})

      assert {:ok, {loaded_user, %Award{} = award}} =
               Badges.create_award(actor(admin), user.slug, %{"badge_id" => badge.id})

      assert loaded_user.id == user.id
      assert Repo.get(Award, award.id).user_id == user.id

      assert [log] = moderation_logs()
      assert log.user_id == admin.id
      assert log.type == "Profile.Award:create"
      assert log.body == "Awarded badge 'Test Award Badge' to #{user.name}"
      assert log.subject_path == "/profiles/#{user.slug}"
    end

    test "a rejected award writes no log and returns the user with the changeset" do
      user = awardee_fixture()

      # No badge_id, so the award changeset is invalid.
      assert {:error, {loaded_user, %Ecto.Changeset{} = changeset, badges}} =
               Badges.create_award(actor(admin_user_fixture()), user.slug, %{})

      assert loaded_user.id == user.id
      refute changeset.valid?
      assert is_list(badges)
      assert Repo.aggregate(Award, :count) == 0
      no_moderation_logs!()
    end

    test "a regular user is unauthorized and writes no log" do
      user = awardee_fixture()
      badge = badge_fixture()

      assert Badges.create_award(actor(confirmed_user_fixture()), user.slug, %{
               "badge_id" => badge.id
             }) ==
               {:error, :unauthorized}

      assert Repo.aggregate(Award, :count) == 0
      no_moderation_logs!()
    end

    test "duplicate grants are intentionally retained as separate awards" do
      moderator = moderator_user_fixture()
      user = awardee_fixture()
      badge = badge_fixture()

      assert {:ok, {_user, first}} =
               Badges.create_award(actor(moderator), user.slug, %{"badge_id" => badge.id})

      assert {:ok, {_user, second}} =
               Badges.create_award(actor(moderator), user.slug, %{"badge_id" => badge.id})

      refute first.id == second.id
      assert Repo.aggregate(Award, :count) == 2
    end
  end

  describe "edit_award/3" do
    test "an admin loads the award and a changeset" do
      admin = admin_user_fixture()
      user = awardee_fixture()
      award = badge_award_fixture(admin, user)

      assert {:ok, {loaded_user, loaded_award, %Ecto.Changeset{}, badges}} =
               Badges.edit_award(actor(admin), user.slug, "#{award.id}")

      assert loaded_user.id == user.id
      assert loaded_award.id == award.id
      assert is_list(badges)
    end

    test "a non-castable award id is not-found" do
      user = awardee_fixture()

      assert Badges.edit_award(actor(admin_user_fixture()), user.slug, "abc") ==
               {:error, :not_found}
    end

    test "an unknown award id is not-found" do
      user = awardee_fixture()

      assert Badges.edit_award(actor(admin_user_fixture()), user.slug, "2147483647") ==
               {:error, :not_found}
    end

    test "an award cannot be loaded through another profile slug" do
      admin = admin_user_fixture()
      owner = awardee_fixture()
      other = awardee_fixture()
      award = badge_award_fixture(admin, owner)

      assert Badges.edit_award(actor(admin), other.slug, award.id) ==
               {:error, :not_found}
    end
  end

  describe "update_award/4" do
    test "an admin updates an award and writes a byte-exact update log" do
      admin = admin_user_fixture()
      user = awardee_fixture()
      award = badge_award_fixture(admin, user, badge_fixture(%{title: "Test Old Badge"}))
      badge = badge_fixture(%{title: "Test Award Badge"})

      assert {:ok, {loaded_user, updated}} =
               Badges.update_award(actor(admin), user.slug, "#{award.id}", %{
                 "badge_id" => "#{badge.id}",
                 "label" => "Best"
               })

      assert loaded_user.id == user.id
      assert %Award{label: "Best", badge_id: badge_id} = Repo.get(Award, updated.id)
      assert badge_id == badge.id

      assert [log] = moderation_logs()
      assert log.user_id == admin.id
      assert log.type == "Profile.Award:update"
      assert log.body == "Updated award of badge 'Test Award Badge' on #{user.name}"
      assert log.subject_path == "/profiles/#{user.slug}"
    end

    test "a mismatched profile slug does not update the award" do
      moderator = moderator_user_fixture()
      owner = awardee_fixture()
      other = awardee_fixture()
      award = badge_award_fixture(moderator, owner, nil, %{label: "Before"})

      assert Badges.update_award(actor(moderator), other.slug, award.id, %{
               "label" => "After"
             }) == {:error, :not_found}

      assert Repo.get(Award, award.id).label == "Before"
      no_moderation_logs!()
    end
  end

  describe "delete_award/3" do
    test "an admin revokes an award, deleting it and writing a byte-exact delete log" do
      admin = admin_user_fixture()
      user = awardee_fixture()
      badge = badge_fixture(%{title: "Test Award Badge"})
      award = badge_award_fixture(admin, user, badge)

      assert {:ok, {loaded_user, revoked}} =
               Badges.delete_award(actor(admin), user.slug, "#{award.id}")

      assert loaded_user.id == user.id
      assert revoked.id == award.id
      assert Repo.get(Award, award.id) == nil

      assert [log] = moderation_logs()
      assert log.user_id == admin.id
      assert log.type == "Profile.Award:delete"
      assert log.body == "Removed badge 'Test Award Badge' from #{user.name}"
      assert log.subject_path == "/profiles/#{user.slug}"
    end

    test "a regular user is unauthorized and writes no log" do
      admin = admin_user_fixture()
      user = awardee_fixture()
      award = badge_award_fixture(admin, user)

      assert Badges.delete_award(actor(confirmed_user_fixture()), user.slug, "#{award.id}") ==
               {:error, :unauthorized}

      assert Repo.get(Award, award.id).id == award.id
      no_moderation_logs!()
    end

    test "a mismatched profile slug does not revoke the award" do
      moderator = moderator_user_fixture()
      owner = awardee_fixture()
      other = awardee_fixture()
      award = badge_award_fixture(moderator, owner)

      assert Badges.delete_award(actor(moderator), other.slug, award.id) ==
               {:error, :not_found}

      assert Repo.get(Award, award.id)
      no_moderation_logs!()
    end
  end

  describe "global write prerequisite" do
    test "badge and award form loaders reject banned but not unattributed staff" do
      admin = admin_user_fixture()
      user = awardee_fixture()
      badge = badge_fixture()
      award = badge_award_fixture(admin, user, badge)

      for operation <- [
            fn actor -> Badges.new_badge(actor) end,
            fn actor -> Badges.edit_badge(actor, badge.id) end,
            fn actor -> Badges.new_award(actor, user.slug) end,
            fn actor -> Badges.edit_award(actor, user.slug, award.id) end
          ] do
        assert operation.(actor(admin, ban: @ban)) == {:error, :ban}
        assert {:ok, _} = operation.(actor(admin, fingerprint: nil))
      end
    end

    test "badge and award mutations reject banned and unattributed staff" do
      admin = admin_user_fixture()
      user = awardee_fixture()
      badge = badge_fixture(%{title: "Unchanged by policy"})
      award = badge_award_fixture(admin, user, badge, %{label: "Unchanged"})

      operations = [
        fn actor -> Badges.create_badge(actor, %{}, nil) end,
        fn actor -> Badges.update_badge(actor, badge.id, %{"title" => "Changed"}) end,
        fn actor -> Badges.update_badge_image(actor, badge.id, nil) end,
        fn actor -> Badges.create_award(actor, user.slug, %{"badge_id" => badge.id}) end,
        fn actor ->
          Badges.update_award(actor, user.slug, award.id, %{"label" => "Changed"})
        end,
        fn actor -> Badges.delete_award(actor, user.slug, award.id) end
      ]

      for operation <- operations do
        assert operation.(actor(admin, ban: @ban)) == {:error, :ban}
        assert operation.(actor(admin, fingerprint: nil)) == {:error, :unauthorized}
      end

      assert Repo.get(Badge, badge.id).title == "Unchanged by policy"
      assert Repo.get(Award, award.id).label == "Unchanged"
      no_moderation_logs!()
    end
  end

  describe "list_badges/2" do
    test "an admin and a Badge-role moderator may list, others may not" do
      _badge = badge_fixture()

      assert {:ok, %Scrivener.Page{}} =
               Badges.list_badges(actor(admin_user_fixture()), @pagination)

      assert {:ok, %Scrivener.Page{}} =
               Badges.list_badges(actor(role_moderator_fixture("Badge")), @pagination)

      assert Badges.list_badges(actor(moderator_user_fixture()), @pagination) ==
               {:error, :unauthorized}

      assert Badges.list_badges(actor(confirmed_user_fixture()), @pagination) ==
               {:error, :unauthorized}

      assert Badges.list_badges(actor(), @pagination) == {:error, :unauthorized}
    end

    test "the listing is ordered by title" do
      beta = badge_fixture(%{title: "Zeta Listing Badge"})
      alpha = badge_fixture(%{title: "Alpha Listing Badge"})

      assert {:ok, page} = Badges.list_badges(actor(admin_user_fixture()), @pagination)

      titles = Enum.map(page.entries, & &1.title)

      assert Enum.find_index(titles, &(&1 == alpha.title)) <
               Enum.find_index(titles, &(&1 == beta.title))
    end
  end

  describe "new_badge/1" do
    test "an admin and a Badge-role moderator get a changeset, others do not" do
      assert {:ok, %Ecto.Changeset{data: %Badge{}}} =
               Badges.new_badge(actor(admin_user_fixture()))

      assert {:ok, %Ecto.Changeset{data: %Badge{}}} =
               Badges.new_badge(actor(role_moderator_fixture("Badge")))

      assert Badges.new_badge(actor(moderator_user_fixture())) == {:error, :unauthorized}
      assert Badges.new_badge(actor()) == {:error, :unauthorized}
    end
  end

  describe "create_badge/3" do
    test "an admin creates a badge through the upload pipeline and writes a byte-exact log" do
      admin = admin_user_fixture()

      assert {:ok, %Badge{} = badge} =
               Badges.create_badge(
                 actor(admin),
                 %{
                   "title" => "Created Badge"
                 },
                 media_svg_upload()
               )

      assert badge.title == "Created Badge"
      assert Repo.get_by(Badge, title: "Created Badge")

      assert [log] = moderation_logs()
      assert log.user_id == admin.id
      assert log.type == "Admin.Badge:create"
      assert log.body == "Created badge 'Created Badge'"
      assert log.subject_path == "/admin/badges"
    end

    test "a Badge-role moderator creates a badge" do
      assert {:ok, %Badge{}} =
               Badges.create_badge(
                 actor(role_moderator_fixture("Badge")),
                 %{
                   "title" => "Mod Created Badge"
                 },
                 media_svg_upload()
               )
    end

    test "a plain moderator is unauthorized and writes no log" do
      assert Badges.create_badge(
               actor(moderator_user_fixture()),
               %{"title" => "nope"},
               media_svg_upload()
             ) == {:error, :unauthorized}

      refute Repo.get_by(Badge, title: "nope")
      no_moderation_logs!()
    end

    test "a missing image is a changeset error and writes no log" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Badges.create_badge(
                 actor(admin_user_fixture()),
                 %{"title" => "No Image Badge"},
                 nil
               )

      refute changeset.valid?
      refute Repo.get_by(Badge, title: "No Image Badge")
      no_moderation_logs!()
    end
  end

  describe "edit_badge/2" do
    test "an admin loads the badge and a changeset" do
      badge = badge_fixture()

      assert {:ok, {loaded, %Ecto.Changeset{}}} =
               Badges.edit_badge(actor(admin_user_fixture()), "#{badge.id}")

      assert loaded.id == badge.id
    end

    test "a plain moderator is unauthorized" do
      badge = badge_fixture()

      assert Badges.edit_badge(actor(moderator_user_fixture()), "#{badge.id}") ==
               {:error, :unauthorized}
    end

    test "a Badge-role moderator is authorized for the edit action" do
      badge = badge_fixture()

      assert {:ok, {%Badge{id: id}, %Ecto.Changeset{}}} =
               Badges.edit_badge(actor(role_moderator_fixture("Badge")), badge.id)

      assert id == badge.id
    end

    test "a non-castable id is not-found" do
      assert Badges.edit_badge(actor(admin_user_fixture()), "abc") ==
               {:error, :not_found}
    end

    test "an unknown id is not-found for a Badge-role moderator and an admin alike" do
      assert Badges.edit_badge(actor(admin_user_fixture()), "2147483647") ==
               {:error, :not_found}

      assert Badges.edit_badge(actor(role_moderator_fixture("Badge")), "2147483647") ==
               {:error, :not_found}
    end
  end

  describe "update_badge/3" do
    test "an admin updates a badge and writes a byte-exact log" do
      admin = admin_user_fixture()
      badge = badge_fixture(%{title: "Before Title"})

      assert {:ok, updated} =
               Badges.update_badge(actor(admin), "#{badge.id}", %{"title" => "After Title"})

      assert updated.title == "After Title"
      assert Repo.get(Badge, badge.id).title == "After Title"

      assert [log] = moderation_logs()
      assert log.user_id == admin.id
      assert log.type == "Admin.Badge:update"
      assert log.body == "Updated badge 'After Title'"
      assert log.subject_path == "/admin/badges"
    end

    test "a plain moderator is unauthorized and writes no log" do
      badge = badge_fixture(%{title: "Unchanged"})

      assert Badges.update_badge(actor(moderator_user_fixture()), "#{badge.id}", %{
               "title" => "changed"
             }) ==
               {:error, :unauthorized}

      assert Repo.get(Badge, badge.id).title == "Unchanged"
      no_moderation_logs!()
    end

    test "a Badge-role moderator is authorized for the update action" do
      badge = badge_fixture()

      assert {:ok, %Badge{title: "Role Updated"}} =
               Badges.update_badge(actor(role_moderator_fixture("Badge")), badge.id, %{
                 "title" => "Role Updated"
               })
    end

    test "an unknown id is not-found" do
      assert Badges.update_badge(actor(admin_user_fixture()), "2147483647", %{"title" => "x"}) ==
               {:error, :not_found}
    end

    test "a blank title is a changeset error and writes no log" do
      badge = badge_fixture(%{title: "Keep This"})

      assert {:error, %Ecto.Changeset{} = changeset} =
               Badges.update_badge(actor(admin_user_fixture()), "#{badge.id}", %{"title" => ""})

      refute changeset.valid?
      assert Repo.get(Badge, badge.id).title == "Keep This"
      no_moderation_logs!()
    end
  end

  describe "update_badge_image/3" do
    test "an admin updates the image through the upload pipeline and writes a byte-exact log" do
      admin = admin_user_fixture()
      badge = badge_fixture(%{title: "Image Badge"})

      assert {:ok, %Badge{}} =
               Badges.update_badge_image(actor(admin), "#{badge.id}", media_svg_upload())

      assert [log] = moderation_logs()
      assert log.user_id == admin.id
      assert log.type == "Admin.Badge.Image:update"
      assert log.body == "Updated image of badge 'Image Badge'"
      assert log.subject_path == "/admin/badges"
    end

    test "a plain moderator is unauthorized and writes no log" do
      badge = badge_fixture()

      assert Badges.update_badge_image(
               actor(moderator_user_fixture()),
               "#{badge.id}",
               media_svg_upload()
             ) == {:error, :unauthorized}

      no_moderation_logs!()
    end

    test "a missing image is a changeset error and preserves the old image" do
      badge = badge_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Badges.update_badge_image(actor(admin_user_fixture()), badge.id, nil)

      refute changeset.valid?
      assert Repo.get!(Badge, badge.id).image == "test.svg"
      no_moderation_logs!()
    end

    test "a Badge-role moderator is authorized for the image-update action" do
      badge = badge_fixture()

      assert {:ok, %Badge{}} =
               Badges.update_badge_image(
                 actor(role_moderator_fixture("Badge")),
                 badge.id,
                 media_svg_upload()
               )
    end

    test "an unknown id is not-found" do
      assert Badges.update_badge_image(
               actor(admin_user_fixture()),
               "2147483647",
               media_svg_upload()
             ) == {:error, :not_found}
    end
  end

  describe "list_badge_users/3" do
    test "an admin loads the badge with the users who hold it" do
      admin = admin_user_fixture()
      badge = badge_fixture()
      user = awardee_fixture()
      _award = badge_award_fixture(admin, user, badge)

      assert {:ok, {loaded, users}} =
               Badges.list_badge_users(actor(admin), "#{badge.id}", @pagination)

      assert loaded.id == badge.id
      assert %Scrivener.Page{} = users
      assert user.id in Enum.map(users.entries, & &1.id)
    end

    test "a plain moderator is unauthorized" do
      badge = badge_fixture()

      assert Badges.list_badge_users(actor(moderator_user_fixture()), "#{badge.id}", @pagination) ==
               {:error, :unauthorized}
    end

    test "a Badge-role moderator is authorized for the show-users action" do
      badge = badge_fixture()

      assert {:ok, {%Badge{}, %Scrivener.Page{}}} =
               Badges.list_badge_users(
                 actor(role_moderator_fixture("Badge")),
                 badge.id,
                 @pagination
               )
    end

    test "a non-castable id is not-found" do
      assert Badges.list_badge_users(actor(admin_user_fixture()), "abc", @pagination) ==
               {:error, :not_found}
    end

    test "an unknown id is not-found" do
      assert Badges.list_badge_users(actor(admin_user_fixture()), "2147483647", @pagination) ==
               {:error, :not_found}
    end
  end
end
