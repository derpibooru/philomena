defmodule PhilomenaWeb.Profile.CommissionControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ArtistLinksFixtures
  import Philomena.CommissionsFixtures
  import Philomena.TagsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Commissions.Commission
  alias Philomena.Repo

  # The commission form is gated on a verified artist link
  # (the :ensure_links_verified plug)
  defp verify_artist_link!(user) do
    tag = tag_fixture(name: "artist:test-commission-artist-#{System.unique_integer([:positive])}")

    verified_artist_link_fixture(user, tag, %{"uri" => "https://example.com/gallery"})
    :ok
  end

  defp valid_commission_params do
    %{
      "information" => "Test commission information",
      "contact" => "Test contact info",
      "open" => "true"
    }
  end

  describe "GET /profiles/:profile_id/commission" do
    test "renders the commission sheet for anonymous users", %{conn: conn} do
      artist = confirmed_user_fixture()
      commission = commission_fixture(artist, %{information: "Custom commission info"})
      item = commission_item_fixture(commission, %{item_type: "Sketch", base_price: 20})

      conn = get(conn, ~p"/profiles/#{artist}/commission")
      response = html_response(conn, 200)

      assert response =~ "Showing Commission - Derpibooru"
      assert response =~ artist.name
      assert response =~ "Custom commission info"
      assert response =~ item.item_type
    end

    test "renders the commission sheet for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      artist = confirmed_user_fixture()
      commission_fixture(artist)

      conn = get(conn, ~p"/profiles/#{artist}/commission")

      assert html_response(conn, 200) =~ "Showing Commission - Derpibooru"
    end

    test "renders commission edit controls only to the owner or a moderator", %{conn: conn} do
      artist = confirmed_user_fixture()
      commission = commission_fixture(artist)
      item = commission_item_fixture(commission)

      owner_response =
        html_response(get(log_in_user(conn, artist), ~p"/profiles/#{artist}/commission"), 200)

      assert owner_response =~ "Edit this listing"
      assert owner_response =~ "Delete this listing"
      assert owner_response =~ "Edit item"
      assert owner_response =~ ~p"/profiles/#{artist}/commission/items/#{item}/edit"

      other_response =
        html_response(
          get(log_in_user(conn, confirmed_user_fixture()), ~p"/profiles/#{artist}/commission"),
          200
        )

      refute other_response =~ "Edit this listing"
      refute other_response =~ "Delete this listing"
      refute other_response =~ "Edit item"

      moderator_response =
        html_response(
          get(log_in_user(conn, moderator_user_fixture()), ~p"/profiles/#{artist}/commission"),
          200
        )

      assert moderator_response =~ "Edit this listing"
      assert moderator_response =~ "Edit item"
    end

    test "redirects to / for a user without a commission", %{conn: conn} do
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/commission")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "redirects to / for an unknown profile", %{conn: conn} do
      conn = get(conn, ~p"/profiles/nonexistent-user/commission")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end

  describe "GET /profiles/:profile_id/commission/new" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/commission/new")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "redirects users without a verified artist link to /commissions", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/profiles/#{user}/commission/new")

      assert redirected_to(conn) == ~p"/commissions"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must have a verified artist link to create a commission listing."
    end

    test "renders the form for a verified artist", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      verify_artist_link!(user)

      response = html_response(get(conn, ~p"/profiles/#{user}/commission/new"), 200)

      assert response =~ "New Commission - Derpibooru"
      assert response =~ "New Commission Listing"
    end

    test "redirects with the authorization flash when a commission already exists",
         %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      verify_artist_link!(user)
      commission_fixture(user)

      conn = get(conn, ~p"/profiles/#{user}/commission/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "redirects with the authorization flash on another user's profile", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      other = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{other}/commission/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the form for a verified artist without a fingerprint", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      verify_artist_link!(user)

      conn = get(without_fingerprint(conn), ~p"/profiles/#{user}/commission/new")

      assert html_response(conn, 200) =~ "New Commission - Derpibooru"
    end
  end

  describe "POST /profiles/:profile_id/commission" do
    test "creates the commission and redirects to it", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      verify_artist_link!(user)

      conn =
        post(conn, ~p"/profiles/#{user}/commission", %{
          "commission" => valid_commission_params()
        })

      assert redirected_to(conn) == ~p"/profiles/#{user}/commission"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Commission successfully created."

      assert Repo.get_by!(Commission, user_id: user.id)
    end

    test "with blank information re-renders the form", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      verify_artist_link!(user)

      conn =
        post(conn, ~p"/profiles/#{user}/commission", %{
          "commission" => %{"information" => "", "contact" => "", "open" => "true"}
        })

      # NOTE: failure re-renders new.html without the :title assign
      assert html_response(conn, 200) =~ "New Commission Listing"
      refute Repo.get_by(Commission, user_id: user.id)
    end

    test "a moderator posting to an artist's profile creates a commission for the artist",
         %{conn: conn} do
      # :ensure_correct_user lets moderators through, and create/2 acts on the
      # profile user (conn.assigns.user) per the on-behalf-of policy - so the
      # commission is created for the artist, not the moderator.
      %{conn: conn, user: moderator} = register_and_log_in_moderator(%{conn: conn})
      artist = confirmed_user_fixture()
      verify_artist_link!(artist)

      conn =
        post(conn, ~p"/profiles/#{artist}/commission", %{
          "commission" => valid_commission_params()
        })

      assert redirected_to(conn) == ~p"/profiles/#{artist}/commission"
      assert Repo.get_by!(Commission, user_id: artist.id)
      refute Repo.get_by(Commission, user_id: moderator.id)
    end

    test "redirects banned users with the ban flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = post(conn, ~p"/profiles/some-user/commission", %{"commission" => %{}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      verify_artist_link!(user)

      conn =
        post(without_fingerprint(conn), ~p"/profiles/#{user}/commission", %{
          "commission" => valid_commission_params()
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(Commission, user_id: user.id)
    end
  end

  describe "GET /profiles/:profile_id/commission/edit" do
    test "renders the form for the commission's owner", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      verify_artist_link!(user)
      commission_fixture(user)

      response = html_response(get(conn, ~p"/profiles/#{user}/commission/edit"), 200)

      assert response =~ "Editing Commission - Derpibooru"
      assert response =~ "Edit Commission Listing"
    end

    test "renders the form for a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      artist = confirmed_user_fixture()
      verify_artist_link!(artist)
      commission_fixture(artist)

      assert html_response(get(conn, ~p"/profiles/#{artist}/commission/edit"), 200) =~
               "Editing Commission - Derpibooru"
    end

    test "redirects another user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      artist = confirmed_user_fixture()
      verify_artist_link!(artist)
      commission_fixture(artist)

      conn = get(conn, ~p"/profiles/#{artist}/commission/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "redirects with the not-found flash when no commission exists", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      verify_artist_link!(user)

      conn = get(conn, ~p"/profiles/#{user}/commission/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "renders the form for the owner without a fingerprint", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      verify_artist_link!(user)
      commission_fixture(user)

      conn = get(without_fingerprint(conn), ~p"/profiles/#{user}/commission/edit")

      assert html_response(conn, 200) =~ "Editing Commission - Derpibooru"
    end
  end

  describe "PATCH /profiles/:profile_id/commission" do
    test "updates the commission and redirects to it", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      verify_artist_link!(user)
      commission_fixture(user)

      conn =
        patch(conn, ~p"/profiles/#{user}/commission", %{
          "commission" => %{"information" => "Updated information", "open" => "false"}
        })

      assert redirected_to(conn) == ~p"/profiles/#{user}/commission"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Commission successfully updated."

      commission = Repo.get_by!(Commission, user_id: user.id)
      assert commission.information == "Updated information"
      refute commission.open
    end

    test "with blank information re-renders the form", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      verify_artist_link!(user)
      commission = commission_fixture(user)

      conn =
        patch(conn, ~p"/profiles/#{user}/commission", %{
          "commission" => %{"information" => ""}
        })

      assert html_response(conn, 200) =~ "Edit Commission Listing"

      assert Repo.get_by!(Commission, user_id: user.id).information ==
               commission.information
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      verify_artist_link!(user)
      commission = commission_fixture(user)

      conn =
        patch(without_fingerprint(conn), ~p"/profiles/#{user}/commission", %{
          "commission" => %{"information" => "Updated information"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.reload!(commission).information == commission.information
    end
  end

  describe "DELETE /profiles/:profile_id/commission" do
    test "deletes the commission and redirects to the directory", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      verify_artist_link!(user)
      commission_fixture(user)

      conn = delete(conn, ~p"/profiles/#{user}/commission")

      assert redirected_to(conn) == ~p"/commissions"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Commission deleted successfully."

      refute Repo.get_by(Commission, user_id: user.id)
    end

    test "redirects another user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      artist = confirmed_user_fixture()
      verify_artist_link!(artist)
      commission_fixture(artist)

      conn = delete(conn, ~p"/profiles/#{artist}/commission")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get_by(Commission, user_id: artist.id)
    end
  end
end
