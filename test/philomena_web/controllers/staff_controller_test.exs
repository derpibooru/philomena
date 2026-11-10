defmodule PhilomenaWeb.StaffControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures

  alias Philomena.Repo

  describe "GET /staff" do
    test "renders the staff list for anonymous users", %{conn: conn} do
      admin = admin_user_fixture(%{name: "Test Site Admin"})
      moderator = moderator_user_fixture(%{name: "Test Site Moderator"})
      assistant = assistant_user_fixture(%{name: "Test Site Assistant"})
      _regular = confirmed_user_fixture(%{name: "Test Regular User"})

      conn = get(conn, ~p"/staff")
      response = html_response(conn, 200)

      assert response =~ "Site Staff - Derpibooru"
      assert response =~ "Administrators"
      assert response =~ admin.name
      assert response =~ "Moderators"
      assert response =~ moderator.name
      assert response =~ "Assistants"
      assert response =~ assistant.name
      refute response =~ "Test Regular User"
    end

    test "lists staff who hide their default role", %{conn: conn} do
      admin =
        admin_user_fixture(%{name: "Test Admin"})
        |> Ecto.Changeset.change(hide_default_role: true)
        |> Repo.update!()

      conn = get(conn, ~p"/staff")
      response = html_response(conn, 200)

      assert response =~ admin.name
    end

    test "categorizes staff by secondary role", %{conn: conn} do
      developer =
        moderator_user_fixture(%{name: "Test Site Developer"})
        |> Ecto.Changeset.change(secondary_role: "Site Developer")
        |> Repo.update!()

      pr =
        assistant_user_fixture(%{name: "Test PR Person"})
        |> Ecto.Changeset.change(secondary_role: "Public Relations")
        |> Repo.update!()

      conn = get(conn, ~p"/staff")
      response = html_response(conn, 200)

      assert response =~ "Technical Team"
      assert response =~ developer.name
      assert response =~ "Public Relations"
      assert response =~ pr.name
    end
  end
end
