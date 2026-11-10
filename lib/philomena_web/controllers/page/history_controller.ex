defmodule PhilomenaWeb.Page.HistoryController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.StaticPages

  action_fallback PhilomenaWeb.FallbackController

  def index(conn, %{"page_id" => slug}) do
    with {:ok, {page, versions}} <-
           StaticPages.list_page_history(conn.assigns.actor, slug) do
      render(conn, "index.html",
        title: "Revision History for Page `#{page.title}'",
        layout_class: "layout--wide",
        static_page: page,
        versions: generate_differences(versions)
      )
    end
  end

  # Versions store the body as it was after each edit, so a version's diff is
  # taken from the next-older version's body to its own. The oldest version is
  # the page's creation and diffs against the empty document.
  defp generate_differences(versions) do
    versions
    |> Enum.reverse()
    |> Enum.map_reduce(nil, fn version, previous_body ->
      difference = MarkdownRenderer.render_diff(previous_body, version.body)

      {%{version | difference: difference}, version.body}
    end)
    |> elem(0)
    |> Enum.reverse()
  end
end
