defmodule PhilomenaWeb.Profile.AwardControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures
  import Philomena.BadgesFixtures

  alias Philomena.Repo
  alias Philomena.Badges.Award

  describe "GET /profiles/:profile_id/awards/new" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      user = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{user}/awards/new")

      assert redirected_to(conn) == ~p"/sessions/new"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      other = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{other}/awards/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the form for a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()
      badge_fixture()

      response = html_response(get(conn, ~p"/profiles/#{other}/awards/new"), 200)

      assert response =~ "New Award - Derpibooru"
      assert response =~ "New award"
    end

    test "renders the form for a moderator without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      conn = get(without_fingerprint(conn), ~p"/profiles/#{other}/awards/new")

      assert html_response(conn, 200) =~ "New Award - Derpibooru"
    end
  end

  describe "POST /profiles/:profile_id/awards" do
    test "creates an award and redirects to the profile", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()
      badge = badge_fixture()

      conn =
        post(conn, ~p"/profiles/#{other}/awards", %{
          "award" => %{"badge_id" => badge.id, "label" => "Nice", "reason" => "for testing"}
        })

      assert redirected_to(conn) == ~p"/profiles/#{other}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Award successfully created."

      award = Repo.get_by!(Award, user_id: other.id, badge_id: badge.id)
      assert award.label == "Nice"
      assert award.reason == "for testing"
    end

    # NOTE: Award.changeset now validate_required badge_id and declares the FK
    # constraint, so a nonexistent badge_id returns {:error, changeset} and the
    # controller re-renders new.html (200) instead of raising. No award persists.
    test "a nonexistent badge_id re-renders the form", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      conn =
        post(conn, ~p"/profiles/#{other}/awards", %{
          "award" => %{"badge_id" => 2_000_000_000}
        })

      assert html_response(conn, 200) =~ "New award"
      refute Repo.get_by(Award, user_id: other.id)
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      other = confirmed_user_fixture()
      badge = badge_fixture()

      conn =
        post(conn, ~p"/profiles/#{other}/awards", %{"award" => %{"badge_id" => badge.id}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      conn =
        post(without_fingerprint(conn), ~p"/profiles/#{other}/awards", %{
          "award" => %{"badge_id" => badge_fixture().id}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(Award, user_id: other.id)
    end
  end

  describe "GET /profiles/:profile_id/awards/:id/edit" do
    test "renders the edit form for a moderator", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()
      award = badge_award_fixture(mod, other)

      response = html_response(get(conn, ~p"/profiles/#{other}/awards/#{award}/edit"), 200)

      assert response =~ "Editing Award - Derpibooru"
      assert response =~ "Editing award"
    end

    test "redirects with the not-found flash for an unknown award id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{other}/awards/#{2_000_000_000}/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer award id short-circuits to NotFoundPlug via the central
    # IntegerId guard, redirecting with the not-found flash.
    test "redirects with the not-found flash for a non-integer award id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      conn = get(conn, ~p"/profiles/#{other}/awards/not-a-number/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    test "redirects with not-found when the award belongs to another profile", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      owner = confirmed_user_fixture()
      other = confirmed_user_fixture()
      award = badge_award_fixture(mod, owner)

      conn = get(conn, ~p"/profiles/#{other}/awards/#{award}/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()
      award = badge_award_fixture(mod, other)

      %{conn: user_conn} = register_and_log_in_user(%{conn: conn})

      conn = get(user_conn, ~p"/profiles/#{other}/awards/#{award}/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the edit form for a moderator without a fingerprint", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()
      award = badge_award_fixture(mod, other)

      conn = get(without_fingerprint(conn), ~p"/profiles/#{other}/awards/#{award}/edit")

      assert html_response(conn, 200) =~ "Editing Award - Derpibooru"
    end
  end

  describe "PATCH /profiles/:profile_id/awards/:id" do
    test "updates the award and redirects to the profile", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()
      award = badge_award_fixture(mod, other)

      conn =
        patch(conn, ~p"/profiles/#{other}/awards/#{award}", %{
          "award" => %{"label" => "Updated label"}
        })

      assert redirected_to(conn) == ~p"/profiles/#{other}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Award successfully updated."
      assert Repo.get!(Award, award.id).label == "Updated label"
    end

    test "PUT also updates the award", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()
      award = badge_award_fixture(mod, other)

      conn =
        put(conn, ~p"/profiles/#{other}/awards/#{award}", %{
          "award" => %{"label" => "Put label"}
        })

      assert redirected_to(conn) == ~p"/profiles/#{other}"
      assert Repo.get!(Award, award.id).label == "Put label"
    end

    # NOTE: same as create - Award.changeset now declares the FK constraint, so
    # reassigning to a nonexistent badge_id returns {:error, changeset} and the
    # controller re-renders edit.html (200); the award keeps its old badge_id.
    test "reassigning to a nonexistent badge_id re-renders the form", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()
      award = badge_award_fixture(mod, other)
      original_badge_id = award.badge_id

      conn =
        patch(conn, ~p"/profiles/#{other}/awards/#{award}", %{
          "award" => %{"badge_id" => 2_000_000_000}
        })

      assert html_response(conn, 200) =~ "Editing award"
      assert Repo.get!(Award, award.id).badge_id == original_badge_id
    end

    test "redirects with the not-found flash for an unknown award id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      conn =
        patch(conn, ~p"/profiles/#{other}/awards/#{2_000_000_000}", %{
          "award" => %{"label" => "x"}
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    test "does not update an award through another profile", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      owner = confirmed_user_fixture()
      other = confirmed_user_fixture()
      award = badge_award_fixture(mod, owner, nil, %{label: "Before"})

      conn =
        patch(conn, ~p"/profiles/#{other}/awards/#{award}", %{
          "award" => %{"label" => "After"}
        })

      assert redirected_to(conn) == "/"
      assert Repo.get!(Award, award.id).label == "Before"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()
      award = badge_award_fixture(mod, other)

      conn =
        patch(without_fingerprint(conn), ~p"/profiles/#{other}/awards/#{award}", %{
          "award" => %{"label" => "Updated label"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get!(Award, award.id).label == award.label
    end
  end

  describe "DELETE /profiles/:profile_id/awards/:id" do
    test "destroys the award and redirects to the profile", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()
      award = badge_award_fixture(mod, other)

      conn = delete(conn, ~p"/profiles/#{other}/awards/#{award}")

      assert redirected_to(conn) == ~p"/profiles/#{other}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Award successfully destroyed. By cruel and unusual means."

      refute Repo.get(Award, award.id)
    end

    test "redirects with the not-found flash for an unknown award id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()

      conn = delete(conn, ~p"/profiles/#{other}/awards/#{2_000_000_000}")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    test "does not revoke an award through another profile", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      owner = confirmed_user_fixture()
      other = confirmed_user_fixture()
      award = badge_award_fixture(mod, owner)

      conn = delete(conn, ~p"/profiles/#{other}/awards/#{award}")

      assert redirected_to(conn) == "/"
      assert Repo.get(Award, award.id)
    end

    test "redirects a regular user with the authorization flash", %{conn: conn} do
      %{conn: conn, user: mod} = register_and_log_in_moderator(%{conn: conn})
      other = confirmed_user_fixture()
      award = badge_award_fixture(mod, other)

      %{conn: user_conn} = register_and_log_in_user(%{conn: conn})

      conn = delete(user_conn, ~p"/profiles/#{other}/awards/#{award}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end
end
