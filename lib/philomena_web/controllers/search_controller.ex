defmodule PhilomenaWeb.SearchController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.ImageLoader
  alias Philomena.Interactions

  def index(conn, params) do
    user = conn.assigns.current_user

    case ImageLoader.search_string(conn, params["q"], include_hits: custom_ordering?(conn)) do
      {:ok, {images, tags}} ->
        interactions = Interactions.user_interactions(images, user)

        conn
        |> render("index.html",
          title: "Searching for #{params["q"]}",
          images: images,
          tags: tags,
          search_query: params["q"],
          interactions: interactions,
          layout_class: "layout--wide"
        )

      {:error, msg} ->
        render(conn, "index.html",
          title: "Searching for #{params["q"]}",
          images: [],
          error: msg,
          search_query: params["q"]
        )
    end
  end

  defp custom_ordering?(%{params: %{"sf" => sf}}) when sf != "id", do: true
  defp custom_ordering?(_conn), do: false
end
