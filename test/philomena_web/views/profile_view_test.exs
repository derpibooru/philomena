defmodule PhilomenaWeb.ProfileViewTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.ArtistLinks.ArtistLink
  alias PhilomenaWeb.ProfileView

  defp visibility(conn, user, target) do
    conn = viewer_conn(conn, user)

    %{
      awards: ProfileView.manages_awards?(conn),
      links: ProfileView.manages_links?(conn, target),
      ban: ProfileView.can_ban?(conn),
      index_user: ProfileView.can_index_user?(conn),
      mod_notes: ProfileView.can_read_mod_notes?(conn, target),
      name_changes: ProfileView.can_see_user_name_changes?(conn, target),
      reveal_anon: ProfileView.can_reveal_anon?(conn)
    }
  end

  describe "profile policy helpers" do
    setup do
      {:ok, target: confirmed_user_fixture()}
    end

    test "anonymous and regular viewers cannot see staff profile tools", %{
      conn: conn,
      target: target
    } do
      expected = %{
        awards: false,
        links: false,
        ban: false,
        index_user: false,
        mod_notes: false,
        name_changes: false,
        reveal_anon: false
      }

      assert visibility(conn, nil, target) == expected
      assert visibility(conn, confirmed_user_fixture(), target) == expected
    end

    test "assistants do not receive moderator-only profile disclosures", %{
      conn: conn,
      target: target
    } do
      assert visibility(conn, assistant_user_fixture(), target) == %{
               awards: false,
               links: false,
               ban: false,
               index_user: false,
               mod_notes: false,
               name_changes: false,
               reveal_anon: false
             }
    end

    test "moderators receive profile management and disclosure helpers", %{
      conn: conn,
      target: target
    } do
      assert visibility(conn, moderator_user_fixture(), target) == %{
               awards: true,
               links: true,
               ban: true,
               index_user: true,
               mod_notes: true,
               name_changes: true,
               reveal_anon: true
             }
    end

    test "admins receive every profile management and disclosure helper", %{
      conn: conn,
      target: target
    } do
      assert visibility(conn, admin_user_fixture(), target) == %{
               awards: true,
               links: true,
               ban: true,
               index_user: true,
               mod_notes: true,
               name_changes: true,
               reveal_anon: true
             }
    end
  end

  describe "should_see_link?/3" do
    setup do
      {:ok, owner: confirmed_user_fixture(), other: confirmed_user_fixture()}
    end

    test "public links are visible to everyone", %{conn: conn, owner: owner, other: other} do
      link = %ArtistLink{user_id: owner.id, public: true}

      assert ProfileView.should_see_link?(viewer_conn(conn, nil), owner, link)

      assert ProfileView.should_see_link?(
               viewer_conn(conn, other),
               other,
               link
             )
    end

    test "private links are visible to their profile owner", %{conn: conn, owner: owner} do
      link = %ArtistLink{user_id: owner.id, public: false}

      assert ProfileView.should_see_link?(viewer_conn(conn, owner), owner, link)
    end

    test "private links are visible to moderators but not other regular users", %{
      conn: conn,
      owner: owner,
      other: other
    } do
      link = %ArtistLink{user_id: owner.id, public: false}

      assert ProfileView.should_see_link?(
               viewer_conn(conn, moderator_user_fixture()),
               owner,
               link
             )

      refute ProfileView.should_see_link?(
               viewer_conn(conn, confirmed_user_fixture()),
               other,
               link
             )
    end
  end
end
