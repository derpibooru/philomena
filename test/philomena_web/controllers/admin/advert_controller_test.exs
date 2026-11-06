defmodule PhilomenaWeb.Admin.AdvertControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.AdvertsFixtures

  alias Philomena.Adverts.Advert
  alias Philomena.Repo

  defp valid_advert_params(extra \\ %{}) do
    Enum.into(extra, %{
      "title" => "Created Advert",
      "link" => "https://example.com/created",
      "start_date" => "now",
      "finish_date" => "1 year from now",
      "restrictions" => "none",
      "image" => png_upload()
    })
  end

  describe "GET /admin/adverts (index) authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = get(conn, ~p"/admin/adverts")
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/admin/adverts")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/adverts")
      assert redirected_to(conn) == "/"
    end

    test "allows a moderator with the Advert role_map entry", %{conn: conn} do
      conn = log_in_role_moderator(conn, "Advert")
      conn = get(conn, ~p"/admin/adverts")
      assert html_response(conn, 200) =~ "New advert"
    end

    test "allows an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/adverts")
      assert html_response(conn, 200) =~ "New advert"
    end
  end

  describe "GET /admin/adverts (index) content" do
    setup [:register_and_log_in_admin]

    test "renders the empty index", %{conn: conn} do
      conn = get(conn, ~p"/admin/adverts")
      response = html_response(conn, 200)
      assert response =~ "Admin - Adverts - Derpibooru"
      assert response =~ "New advert"
    end

    test "lists an existing advert", %{conn: conn} do
      advert = advert_fixture()
      conn = get(conn, ~p"/admin/adverts")
      assert html_response(conn, 200) =~ advert.title
    end
  end

  describe "GET /admin/adverts/new" do
    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/adverts/new")
      assert redirected_to(conn) == "/"
    end

    test "renders the form for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/adverts/new")
      response = html_response(conn, 200)
      assert response =~ "New Advert - Derpibooru"
      assert response =~ "New advert"
    end

    test "renders the form for an admin without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/admin/adverts/new")

      assert html_response(conn, 200) =~ "New Advert - Derpibooru"
    end
  end

  describe "POST /admin/adverts (create)" do
    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(conn, ~p"/admin/adverts", %{"advert" => valid_advert_params(%{"title" => "nope"})})

      assert redirected_to(conn) == "/"
      refute Repo.get_by(Advert, title: "nope")
    end

    test "creates an advert as an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = post(conn, ~p"/admin/adverts", %{"advert" => valid_advert_params()})
      assert redirected_to(conn) == ~p"/admin/adverts"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Advert was successfully created."
      assert Repo.get_by(Advert, title: "Created Advert")
    end

    test "creates an advert as an Advert-role moderator", %{conn: conn} do
      conn = log_in_role_moderator(conn, "Advert")

      conn =
        post(conn, ~p"/admin/adverts", %{
          "advert" => valid_advert_params(%{"title" => "Mod Advert"})
        })

      assert redirected_to(conn) == ~p"/admin/adverts"
      assert Repo.get_by(Advert, title: "Mod Advert")
    end

    # NOTE: Unlike the badge controller, the advert controller's create/2 error
    # branch matches `{:error, changeset}` (what `create_advert/1` actually
    # returns), so a validation failure re-renders the form (200) rather than
    # crashing.
    test "re-renders the form on a validation failure", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = post(conn, ~p"/admin/adverts", %{"advert" => valid_advert_params(%{"title" => ""})})
      assert html_response(conn, 200) =~ "New advert"
      refute Repo.get_by(Advert, link: "https://example.com/created")
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        post(without_fingerprint(conn), ~p"/admin/adverts", %{"advert" => valid_advert_params()})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(Advert, title: "Created Advert")
    end
  end

  describe "GET /admin/adverts/:id/edit" do
    test "rejects a plain moderator", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(conn, ~p"/admin/adverts/#{advert}/edit")
      assert redirected_to(conn) == "/"
    end

    test "renders the edit form for an admin", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/adverts/#{advert}/edit")
      response = html_response(conn, 200)
      assert response =~ "Editing Advert - Derpibooru"
      assert response =~ "Editing advert"
    end

    test "redirects with a not-found flash for an unknown id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = get(conn, ~p"/admin/adverts/#{2_000_000_000}/edit")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects with a not-found flash for a non-integer id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/admin/adverts/not-a-number/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "renders the edit form for an admin without a fingerprint", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/admin/adverts/#{advert}/edit")

      assert html_response(conn, 200) =~ "Editing Advert - Derpibooru"
    end
  end

  describe "PATCH /admin/adverts/:id (update)" do
    test "rejects a plain moderator", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = patch(conn, ~p"/admin/adverts/#{advert}", %{"advert" => %{"title" => "changed"}})
      assert redirected_to(conn) == "/"
    end

    test "updates the advert as an admin", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(conn, ~p"/admin/adverts/#{advert}", %{"advert" => %{"title" => "Renamed Advert"}})

      assert redirected_to(conn) == ~p"/admin/adverts"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Advert was successfully updated."
      assert Repo.get(Advert, advert.id).title == "Renamed Advert"
    end

    test "re-renders the edit form on a validation failure", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = patch(conn, ~p"/admin/adverts/#{advert}", %{"advert" => %{"title" => ""}})
      assert html_response(conn, 200) =~ "Editing advert"
      refute Repo.get(Advert, advert.id).title == ""
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        patch(without_fingerprint(conn), ~p"/admin/adverts/#{advert}", %{
          "advert" => %{"title" => "Renamed Advert"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(Advert, advert.id).title == advert.title
    end
  end

  describe "PUT /admin/adverts/:id (update)" do
    test "updates the advert as an admin", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = put(conn, ~p"/admin/adverts/#{advert}", %{"advert" => %{"title" => "Put Renamed"}})
      assert redirected_to(conn) == ~p"/admin/adverts"
      assert Repo.get(Advert, advert.id).title == "Put Renamed"
    end
  end

  describe "DELETE /admin/adverts/:id" do
    test "rejects a plain moderator", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = delete(conn, ~p"/admin/adverts/#{advert}")
      assert redirected_to(conn) == "/"
      assert Repo.get(Advert, advert.id)
    end

    test "deletes the advert as an admin", %{conn: conn} do
      advert = advert_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      conn = delete(conn, ~p"/admin/adverts/#{advert}")
      assert redirected_to(conn) == ~p"/admin/adverts"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Advert was successfully deleted."
      refute Repo.get(Advert, advert.id)
    end

    test "deletes the advert as an Advert-role moderator", %{conn: conn} do
      advert = advert_fixture()
      conn = log_in_role_moderator(conn, "Advert")
      conn = delete(conn, ~p"/admin/adverts/#{advert}")
      assert redirected_to(conn) == ~p"/admin/adverts"
      refute Repo.get(Advert, advert.id)
    end
  end
end
