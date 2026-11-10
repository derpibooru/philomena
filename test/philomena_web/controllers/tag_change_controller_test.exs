defmodule PhilomenaWeb.TagChangeControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  # The read-only :index action and the moderation :delete action are both
  # covered here.

  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Images
  alias Philomena.Repo
  alias Philomena.TagChanges.TagChange
  alias Philomena.Tags.Tag
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  import Ecto.Query

  setup do
    Search.clear_index!(TagChange)
    # Valkey rate-limit counters are not rolled back by the SQL sandbox; reset
    # the tag-change limit so accumulated counts don't trip check_limits.
    reset_tag_change_limits()
    :ok
  end

  defp tag_change_fixture!(
         user,
         added_tags \\ "added test tag, other added tag",
         actor_opts \\ []
       ) do
    image = image_fixture()

    # The tag changeset requires at least 3 tags, so the update keeps the
    # fixture's "safe" tag and adds two more.
    {:ok, _} =
      Images.update_image_tags(actor(user, actor_opts), image.id, %{
        "old_tag_input" => "safe",
        "tag_input" => "safe, #{added_tags}"
      })

    SearchHelpers.reindex_all!(TagChange)
    image
  end

  # Returns the single TagChange row created for `image`. The moderation-log
  # detail formatter pattern-matches `%{user: %{name: name}}`, so the change
  # must be authored by a real user (an anonymous change would crash the log).
  defp tag_change_row!(image) do
    Repo.one!(from tc in TagChange, where: tc.image_id == ^image.id)
  end

  describe "GET /tag_changes" do
    test "lists tag changes for anonymous users", %{conn: conn} do
      user = confirmed_user_fixture()
      image = tag_change_fixture!(user)

      conn = get(conn, ~p"/tag_changes")
      response = html_response(conn, 200)

      assert response =~ "Tag Changes - Derpibooru"
      assert response =~ "added test tag"
      assert response =~ ~p"/images/#{image}"
      assert response =~ user.name
    end

    test "renders with no tag changes", %{conn: conn} do
      conn = get(conn, ~p"/tag_changes")

      assert html_response(conn, 200) =~ "Tag Changes - Derpibooru"
    end

    test "filters by tcq query", %{conn: conn} do
      user = confirmed_user_fixture()
      image = tag_change_fixture!(user)

      conn = get(conn, ~p"/tag_changes?#{[tcq: "image_id:#{image.id}"]}")
      response = html_response(conn, 200)

      assert response =~ "added test tag"

      conn = get(conn, ~p"/tag_changes?#{[tcq: "image_id:#{image.id + 1}"]}")
      response = html_response(conn, 200)

      refute response =~ "added test tag"
    end

    test "invalid query-form input redirects with an error", %{conn: conn} do
      conn = get(conn, ~p"/tag_changes?#{[sf: "unknown"]}")

      assert redirected_to(conn) == ~p"/tag_changes"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid tag change query."
    end

    test "an image route filters the listing to that image's changes", %{conn: conn} do
      image = tag_change_fixture!(confirmed_user_fixture(), "filtered marker tag, second tag")

      _other_image =
        tag_change_fixture!(confirmed_user_fixture(), "unrelated marker tag, second tag")

      conn = get(conn, ~p"/images/#{image}/tag_changes")
      response = html_response(conn, 200)

      assert response =~ "Tag Changes for Image ##{image.id}"

      # ...and the resource params now also filter the listing: only the
      # requested image's change appears, the unrelated one is absent.
      assert response =~ "filtered marker tag"
      refute response =~ "unrelated marker tag"
    end

    test "missing and malformed image resources use the not-found response", %{conn: conn} do
      conn = get(conn, ~p"/images/not-an-id/tag_changes")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"

      conn = get(conn, ~p"/images/2147483647/tag_changes")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "a tag route filters the listing to that tag's changes", %{conn: conn} do
      tag_change_fixture!(confirmed_user_fixture())
      tag = Repo.get_by!(Tag, name: "added test tag")
      conn = log_in_user(conn, moderator_user_fixture())

      response = html_response(get(conn, ~p"/tags/#{tag}/tag_changes"), 200)

      assert response =~ "Tag Changes for Tag"
      assert response =~ "added test tag"
    end

    test "hidden image history ignores image visibility", %{conn: conn} do
      image = tag_change_fixture!(confirmed_user_fixture(), "hidden marker tag, second tag")

      image
      |> Ecto.Changeset.change(hidden_from_users: true)
      |> Repo.update!()

      SearchHelpers.reindex_all!(TagChange)

      response = html_response(get(conn, ~p"/tag_changes"), 200)
      assert response =~ "hidden marker tag"

      conn = get(conn, ~p"/images/#{image}/tag_changes")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"

      moderator_conn = log_in_user(recycle(conn), moderator_user_fixture())

      response = html_response(get(moderator_conn, ~p"/tag_changes"), 200)
      assert response =~ "hidden marker tag"

      response =
        html_response(
          get(
            moderator_conn,
            ~p"/images/#{image}/tag_changes"
          ),
          200
        )

      assert response =~ "hidden marker tag"
    end

    test "a profile route filters the listing to that user's changes", %{conn: conn} do
      user = confirmed_user_fixture()
      tag_change_fixture!(user, "filtered marker tag, second tag")
      tag_change_fixture!(confirmed_user_fixture(), "unrelated marker tag, second tag")

      conn = get(conn, ~p"/profiles/#{user}/tag_changes")

      response = html_response(conn, 200)

      assert response =~ "filtered marker tag"
      refute response =~ "unrelated marker tag"
    end

    test "discloses tag-change identity metadata only to authorized viewers", %{conn: conn} do
      user = confirmed_user_fixture()

      tag_change_fixture!(user, "identity marker tag, second tag",
        ip: %Postgrex.INET{address: {198, 51, 100, 25}, netmask: 32},
        fingerprint: "ctagchange"
      )

      anonymous_response = html_response(get(conn, ~p"/tag_changes"), 200)
      refute anonymous_response =~ "198.51.100.25"
      refute anonymous_response =~ "ctagchange"

      moderator_response =
        html_response(get(log_in_user(conn, moderator_user_fixture()), ~p"/tag_changes"), 200)

      assert moderator_response =~ "198.51.100.25"
      assert moderator_response =~ "ctagcha"
    end

    test "tcq composes with an image route as AND", %{conn: conn} do
      user = confirmed_user_fixture()
      image = tag_change_fixture!(user)
      other_image = image_fixture()

      # tcq matching + resource filter pointing at the same image: listed.
      conn1 =
        get(
          conn,
          ~p"/images/#{image}/tag_changes?#{[tcq: "image_id:#{image.id}"]}"
        )

      assert html_response(conn1, 200) =~ "added test tag"

      # The same tcq joined with a resource filter for a change-free image
      # matches nothing.
      conn2 =
        get(
          conn,
          ~p"/images/#{other_image}/tag_changes?#{[tcq: "image_id:#{image.id}"]}"
        )

      refute html_response(conn2, 200) =~ "added test tag"
    end

    test "an IP route is forbidden to non-staff viewers", %{conn: conn} do
      tag_change_fixture!(confirmed_user_fixture())

      conn = get(conn, ~p"/ip_profiles/203.0.113.1/tag_changes")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "a moderator can filter by ip; an invalid ip is not found", %{conn: conn} do
      tag_change_fixture!(confirmed_user_fixture())

      conn = log_in_user(conn, moderator_user_fixture())

      conn1 = get(conn, ~p"/ip_profiles/203.0.113.1/tag_changes")
      assert html_response(conn1, 200) =~ "added test tag"

      conn2 = get(conn, ~p"/ip_profiles/not-an-ip/tag_changes")
      assert redirected_to(conn2) == "/"
      assert Phoenix.Flash.get(conn2.assigns.flash, :error) =~ "Couldn't find"
    end

    test "fingerprint resources validate and require identity access", %{conn: conn} do
      tag_change_fixture!(confirmed_user_fixture())

      conn =
        get(
          conn,
          ~p"/fingerprint_profiles/d015c342859dde3/tag_changes"
        )

      assert redirected_to(conn) == ~p"/sessions/new"

      moderator_conn = log_in_user(recycle(conn), moderator_user_fixture())

      response =
        html_response(
          get(
            moderator_conn,
            ~p"/fingerprint_profiles/D015C342859DDE3/tag_changes"
          ),
          200
        )

      assert response =~ "added test tag"

      conn =
        get(
          moderator_conn,
          ~p"/fingerprint_profiles/invalid/tag_changes"
        )

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "DELETE /tag_changes/:id" do
    test "is rejected for anonymous users", %{conn: conn} do
      user = confirmed_user_fixture()
      image = tag_change_fixture!(user)
      tc = tag_change_row!(image)

      # NOTE: /tag_changes sits in the Tor-authorized scope, not the
      # login-required one, so an anonymous visitor gets {:error, :unauthorized}
      # from the context (redirect to "/" with the can't-access flash) rather
      # than a login redirect.
      conn = delete(conn, ~p"/tag_changes/#{tc}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
      assert Repo.get(TagChange, tc.id)
    end

    test "is rejected for regular users", %{conn: conn} do
      user = confirmed_user_fixture()
      image = tag_change_fixture!(user)
      tc = tag_change_row!(image)

      conn = log_in_user(conn, confirmed_user_fixture())
      conn = delete(conn, ~p"/tag_changes/#{tc}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "can't access"
      assert Repo.get(TagChange, tc.id)
    end

    test "a moderator deletes the tag change and is redirected back", %{conn: conn} do
      user = confirmed_user_fixture()
      image = tag_change_fixture!(user)
      tc = tag_change_row!(image)
      referrer = "http://localhost/images/#{image.id}/tag_changes"

      conn =
        conn
        |> log_in_user(moderator_user_fixture())
        |> put_req_header("referer", referrer)
        |> delete(~p"/tag_changes/#{tc}")

      assert redirected_to(conn) == referrer
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Successfully deleted tag change"
      refute Repo.get(TagChange, tc.id)
    end

    test "an unknown id takes the not-found redirect", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())

      conn = delete(conn, ~p"/tag_changes/#{123_456_789}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "a non-integer id redirects with the not-found flash", %{conn: conn} do
      conn = log_in_user(conn, moderator_user_fixture())

      conn = delete(conn, ~p"/tag_changes/not-an-integer")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
