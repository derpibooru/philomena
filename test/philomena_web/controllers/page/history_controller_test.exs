defmodule PhilomenaWeb.Page.HistoryControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.StaticPagesFixtures
  import Philomena.AttributionFixtures, only: [actor: 1]
  import Philomena.UsersFixtures

  alias Philomena.StaticPages

  describe "GET /pages/:page_id/history" do
    test "renders the revision history for anonymous users", %{conn: conn} do
      creator = user_fixture()
      editor = admin_user_fixture()
      page = static_page_fixture(creator, %{body: "The original text"})

      {:ok, _page} =
        StaticPages.update_page(actor(editor), page.slug, %{
          title: page.title,
          slug: page.slug,
          body: "The updated text"
        })

      conn = get(conn, ~p"/pages/#{page}/history")
      response = html_response(conn, 200)

      assert response =~ "Revision History for Page"
      assert response =~ page.title
      # The body renders as a line-by-line unified diff table over the raw
      # markdown source. A word changed in place highlights the deleted word on
      # the old-line row and the inserted word on the new-line row.
      assert response =~ ~s(<table class="diff">)
      assert response =~ ~s(<del class="diff__hl">original</del>)
      assert response =~ ~s(<ins class="diff__hl">updated</ins>)

      # Versions list newest-first, and each row shows the change that edit
      # made: the edit diff belongs to the editor's row (above the creator's).
      editor_at = elem(:binary.match(response, editor.name), 0)
      creator_at = elem(:binary.match(response, creator.name), 0)
      edit_diff_at = elem(:binary.match(response, ~s(<del class="diff__hl">original</del>)), 0)
      assert editor_at < edit_diff_at
      assert edit_diff_at < creator_at

      # The creation version diffs against the empty document, so the original
      # body shows as a whole inserted line.
      assert response =~
               ~s(<tr class="diff__row diff__row--ins"><td class="diff__gutter"></td>) <>
                 ~s(<td class="diff__gutter">1</td><td class="diff__text">The original text</td></tr>)
    end

    test "renders the initial version for a never-edited page", %{conn: conn} do
      page = static_page_fixture(user_fixture(), %{body: "Test page body"})

      conn = get(conn, ~p"/pages/#{page}/history")
      response = html_response(conn, 200)

      assert response =~ "Revision History for Page"
      assert response =~ page.title
      # The sole (creation) version diffs against the empty document.
      assert response =~
               ~s(<tr class="diff__row diff__row--ins"><td class="diff__gutter"></td>) <>
                 ~s(<td class="diff__gutter">1</td><td class="diff__text">Test page body</td></tr>)
    end

    test "redirects with the not-found flash for an unknown slug", %{conn: conn} do
      conn = get(conn, ~p"/pages/nonexistent-page/history")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end
end
