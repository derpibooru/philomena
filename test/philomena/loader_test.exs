defmodule Philomena.LoaderTest do
  use Philomena.DataCase, async: true

  import Ecto.Query
  import Philomena.AttributionFixtures, only: [actor: 0, actor: 1]
  import Philomena.SiteNoticesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Loader
  alias Philomena.SiteNotices.SiteNotice

  describe "parse_id/1" do
    test "normalizes malformed IDs to not found" do
      assert Loader.parse_id("42") == {:ok, 42}
      assert Loader.parse_id("not-an-id") == {:error, :not_found}
    end
  end

  describe "fetch_and_authorize/5" do
    setup do
      notice = site_notice_fixture()

      actors = [
        anonymous: actor(),
        user: actor(confirmed_user_fixture()),
        moderator: actor(moderator_user_fixture()),
        admin: actor(admin_user_fixture())
      ]

      %{actors: actors, notice: notice}
    end

    test "malformed and missing IDs are not found for every actor", %{actors: actors} do
      for {_role, actor} <- actors do
        assert Loader.fetch_and_authorize(SiteNotice, actor, :edit, "not-an-id") ==
                 {:error, :not_found}

        assert Loader.fetch_and_authorize(SiteNotice, actor, :edit, 2_147_483_647) ==
                 {:error, :not_found}
      end
    end

    test "authorization is evaluated only for a real record", %{actors: actors, notice: notice} do
      for {role, actor} <- actors do
        expected =
          if role == :admin do
            {:ok, notice}
          else
            {:error, :unauthorized}
          end

        assert Loader.fetch_and_authorize(SiteNotice, actor, :edit, notice.id) == expected
      end
    end
  end

  describe "query-based loaders" do
    test "one/1 normalizes an empty result" do
      assert Loader.one(from notice in SiteNotice, where: notice.id == -1) ==
               {:error, :not_found}
    end

    test "one_and_authorize/3 preserves missing before forbidden precedence" do
      user = actor(confirmed_user_fixture())

      assert Loader.one_and_authorize(
               from(notice in SiteNotice, where: notice.id == -1),
               user,
               :edit
             ) == {:error, :not_found}

      notice = site_notice_fixture()

      assert Loader.one_and_authorize(
               from(candidate in SiteNotice, where: candidate.id == ^notice.id),
               user,
               :edit
             ) == {:error, :unauthorized}
    end
  end
end
