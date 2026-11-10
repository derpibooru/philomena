defmodule PhilomenaWeb.Image.ScratchpadControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.ImagesFixtures

  alias Philomena.Repo

  defp scratchpad(image), do: Repo.reload!(image).scratchpad

  describe "GET /images/:image_id/scratchpad/edit" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/scratchpad/edit")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/scratchpad/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the mod-notes form for a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/scratchpad/edit")
      response = html_response(conn, 200)

      assert response =~ "Editing Moderation Notes - Derpibooru"
      assert response =~ "Editing moderation notes for image"
    end

    test "renders the mod-notes form for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}/scratchpad/edit")

      assert html_response(conn, 200) =~ "Editing moderation notes for image"
    end

    test "for an unknown image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/images/999999999/scratchpad/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer image_id short-circuits to NotFoundPlug via the central
    # IntegerId guard before authorization runs.
    test "for a non-integer image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/images/not-a-number/scratchpad/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end

  describe "PATCH/PUT /images/:image_id/scratchpad" do
    test "redirects anonymous users to login", %{conn: conn} do
      image = image_fixture()

      conn =
        put(conn, ~p"/images/#{image}/scratchpad", %{"image" => %{"scratchpad" => "notes"}})

      assert redirected_to(conn) == ~p"/sessions/new"
      assert scratchpad(image) == nil
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn =
        put(conn, ~p"/images/#{image}/scratchpad", %{"image" => %{"scratchpad" => "notes"}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert scratchpad(image) == nil
    end

    test "as a moderator updates the mod notes", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture()

      conn =
        put(conn, ~p"/images/#{image}/scratchpad", %{
          "image" => %{"scratchpad" => "spammer, watch closely"}
        })

      assert redirected_to(conn) == ~p"/images/#{image}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully updated moderation notes."

      assert scratchpad(image) == "spammer, watch closely"
    end

    test "as an admin updates the mod notes", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})
      image = image_fixture()

      conn =
        put(conn, ~p"/images/#{image}/scratchpad", %{"image" => %{"scratchpad" => "seen"}})

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully updated moderation notes."

      assert scratchpad(image) == "seen"
    end

    # NOTE: a blank scratchpad is a valid update; cast/3 treats "" as an empty
    # value and stores nil, clearing the notes.
    test "clears the mod notes with a blank value", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      image = image_fixture(scratchpad: "old notes")

      conn =
        put(conn, ~p"/images/#{image}/scratchpad", %{"image" => %{"scratchpad" => ""}})

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully updated moderation notes."

      assert scratchpad(image) == nil
    end

    test "for an unknown image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        put(conn, ~p"/images/999999999/scratchpad", %{"image" => %{"scratchpad" => "notes"}})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end

    # NOTE: a non-integer image_id short-circuits to NotFoundPlug via the central
    # IntegerId guard before authorization runs.
    test "for a non-integer image_id redirects with the not-found flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        put(conn, ~p"/images/not-a-number/scratchpad", %{"image" => %{"scratchpad" => "notes"}})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end
end
