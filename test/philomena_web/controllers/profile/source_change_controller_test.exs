defmodule PhilomenaWeb.Profile.SourceChangeControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias Philomena.Images

  defp source_change!(user, source, actor_opts \\ []) do
    image = image_fixture()

    {:ok, _} =
      Images.update_image_sources(actor(user, actor_opts), image.id, %{
        "old_sources" => %{},
        "sources" => %{"0" => %{"source" => source}}
      })

    image
  end

  describe "GET /profiles/:profile_id/source_changes" do
    test "allows anonymous viewers for a real profile", %{conn: conn} do
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/source_changes")

      assert html_response(conn, 200)
    end

    test "lists a user's source changes for moderators", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      user = confirmed_user_fixture()
      source_change!(user, "https://example.com/profile-source")

      conn = get(conn, ~p"/profiles/#{user}/source_changes")
      response = html_response(conn, 200)

      assert response =~ "Source Changes for User"
      assert response =~ user.name
      assert response =~ "https://example.com/profile-source"
    end

    test "renders with no source changes", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/source_changes")

      assert html_response(conn, 200) =~ "Source Changes for User"
    end

    test "filters to removals with added=0", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      user = confirmed_user_fixture()
      source_change!(user, "https://example.com/added-source")

      conn = get(conn, ~p"/profiles/#{user}/source_changes?#{[added: 0]}")
      response = html_response(conn, 200)

      assert response =~ "Source Changes for User"
      refute response =~ "https://example.com/added-source"
    end

    test "allows a regular user for a real profile", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/source_changes")

      assert html_response(conn, 200)
    end

    test "uses the not-found response for an unknown profile", %{conn: conn} do
      conn = get(conn, ~p"/profiles/nonexistent-user/source_changes")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects with an error flash for an invalid filter", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/source_changes?added=invalid")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid source change filter."
    end

    test "discloses source-change identity metadata only to authorized viewers", %{conn: conn} do
      user = confirmed_user_fixture()

      source_change!(user, "https://example.com/identity-source",
        ip: %Postgrex.INET{address: {198, 51, 100, 24}, netmask: 32},
        fingerprint: "csourcechange"
      )

      anonymous_response =
        html_response(get(conn, ~p"/profiles/#{user}/source_changes"), 200)

      refute anonymous_response =~ "198.51.100.24"
      refute anonymous_response =~ "csourcechange"

      regular_response =
        html_response(
          get(
            log_in_user(conn, confirmed_user_fixture()),
            ~p"/profiles/#{user}/source_changes"
          ),
          200
        )

      refute regular_response =~ "198.51.100.24"
      refute regular_response =~ "csourcechange"

      moderator_response =
        html_response(
          get(
            log_in_user(conn, moderator_user_fixture()),
            ~p"/profiles/#{user}/source_changes"
          ),
          200
        )

      assert moderator_response =~ "198.51.100.24"
      assert moderator_response =~ "csource"
    end
  end
end
