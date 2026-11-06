defmodule PhilomenaWeb.Image.NavigateControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.ImagesFixtures

  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Images.Image

  setup do
    Search.clear_index!(Image)
    :ok
  end

  defp two_images do
    older = image_fixture(first_seen_at: hours_ago(2))
    newer = image_fixture(first_seen_at: hours_ago(1))
    SearchHelpers.reindex_all!(Image)

    {older, newer}
  end

  describe "GET /images/:image_id/navigate?rel=next" do
    # The default sort is first_seen_at descending, so "next" moves towards
    # older images.
    test "redirects to the next image in the sequence", %{conn: conn} do
      {older, newer} = two_images()

      conn = get(conn, ~p"/images/#{newer}/navigate?rel=next")

      assert redirected_to(conn) =~ ~p"/images/#{older.id}"
    end

    test "redirects back to the same image at the end of the sequence", %{conn: conn} do
      {older, _newer} = two_images()

      conn = get(conn, ~p"/images/#{older}/navigate?rel=next")

      assert redirected_to(conn) == ~p"/images/#{older.id}?"
    end
  end

  describe "GET /images/:image_id/navigate with a query the viewer cannot run" do
    test "stays on the image and shows the query error", %{conn: conn} do
      {_older, newer} = two_images()

      conn = get(conn, ~p"/images/#{newer}/navigate?rel=next&q=my:faves")

      assert redirected_to(conn) =~ ~p"/images/#{newer.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "logged in"
    end
  end

  describe "GET /images/:image_id/navigate?rel=prev" do
    test "redirects to the previous image in the sequence", %{conn: conn} do
      {older, newer} = two_images()

      conn = get(conn, ~p"/images/#{older}/navigate?rel=prev")

      assert redirected_to(conn) =~ ~p"/images/#{newer.id}"
    end
  end

  describe "GET /images/:image_id/navigate?rel=find" do
    test "redirects to the search page containing the image", %{conn: conn} do
      {older, _newer} = two_images()

      conn = get(conn, ~p"/images/#{older}/navigate?rel=find")

      assert redirected_to(conn) == ~p"/search?#{[q: "*", page: "1", sf: "id"]}"
    end
  end

  describe "failure paths" do
    test "crashes without a rel parameter", %{conn: conn} do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      assert_raise Phoenix.ActionClauseError, fn ->
        get(conn, ~p"/images/#{image}/navigate")
      end
    end

    test "redirects to / for an unknown image", %{conn: conn} do
      conn = get(conn, ~p"/images/999999999/navigate?rel=next")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end
  end

  defp hours_ago(hours) do
    DateTime.utc_now()
    |> DateTime.add(-hours * 3600, :second)
    |> DateTime.truncate(:second)
  end
end
