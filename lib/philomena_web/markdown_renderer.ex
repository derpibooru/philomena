defmodule PhilomenaWeb.MarkdownRenderer do
  alias Philomena.Markdown
  alias Philomena.Images.Image
  alias Philomena.Repo
  import Phoenix.HTML
  import Phoenix.HTML.Link
  import Ecto.Query

  @image_view Module.concat(["PhilomenaWeb.ImageView"])

  def render_one(item, conn) do
    hd(render_collection([item], conn))
  end

  def render_collection(collection, conn) do
    representations =
      collection
      |> Enum.flat_map(fn %{body: text} ->
        find_images(text)
      end)
      |> render_representations(conn)

    Enum.map(collection, fn %{body: text} ->
      Markdown.to_html(text, representations)
    end)
  end

  def render_unsafe(text, conn) do
    images = find_images(text)
    representations = render_representations(images, conn)

    Markdown.to_html_unsafe(text, representations)
  end

  defp find_images(text) do
    Regex.scan(~r/>>(\d+)([tsp])?/, text, capture: :all_but_first)
    |> Enum.map(fn matches ->
      [Enum.at(matches, 0) |> String.to_integer(), Enum.at(matches, 1) || ""]
    end)
    |> Enum.filter(fn m -> Enum.at(m, 0) < 2_147_483_647 end)
  end

  defp load_images(images) do
    ids = Enum.map(images, fn m -> Enum.at(m, 0) end)

    Image
    |> where([i], i.id in ^ids)
    |> preload(tags: :aliases)
    |> Repo.all()
    |> Map.new(&{&1.id, &1})
  end

  defp link_suffix(image) do
    cond do
      not is_nil(image.duplicate_id) ->
        " (merged)"

      image.hidden_from_users ->
        " (deleted)"

      true ->
        ""
    end
  end

  defp render_representations(images, conn) do
    loaded_images = load_images(images)

    images
    |> Enum.map(fn group ->
      img = loaded_images[Enum.at(group, 0)]
      text = "#{Enum.at(group, 0)}#{Enum.at(group, 1)}"

      rendered =
        cond do
          img != nil ->
            case group do
              [_id, "p"] when not img.hidden_from_users ->
                Phoenix.View.render(@image_view, "_image_target.html",
                  image: img,
                  size: :medium,
                  conn: conn
                )
                |> safe_to_string()

              [_id, "t"] when not img.hidden_from_users ->
                Phoenix.View.render(@image_view, "_image_target.html",
                  image: img,
                  size: :small,
                  conn: conn
                )
                |> safe_to_string()

              [_id, "s"] when not img.hidden_from_users ->
                Phoenix.View.render(@image_view, "_image_target.html",
                  image: img,
                  size: :thumb_small,
                  conn: conn
                )
                |> safe_to_string()

              [_id, ""] ->
                link(">>#{img.id}#{link_suffix(img)}", to: "/images/#{img.id}")
                |> safe_to_string()

              [_id, suffix] when suffix in ["t", "s", "p"] ->
                link(">>#{img.id}#{suffix}#{link_suffix(img)}", to: "/images/#{img.id}")
                |> safe_to_string()

              # This condition should never trigger, but let's leave it here just in case.
              [id, suffix] ->
                ">>#{id}#{suffix}"
            end

          true ->
            ">>#{text}"
        end

      [text, rendered]
    end)
    |> Map.new(fn [id, html] -> {id, html} end)
  end
end
