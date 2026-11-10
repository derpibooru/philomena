defmodule PhilomenaWeb.MarkdownRenderer do
  alias Philomena.Markdown
  alias Philomena.Images
  alias PhilomenaWeb.ImageView
  import Phoenix.HTML.Link

  # TODO: collection_renderer pattern is a weird inversion of control
  # that is no longer needed. It should flow one way from context to web

  def render_one(item, conn) do
    hd(render_collection([item], conn))
  end

  # This is rendered Markdown
  # sobelow_skip ["XSS.Raw"]
  def render_collection(collection, conn) do
    representations =
      collection
      |> Enum.flat_map(fn %{body: text} ->
        find_images(text || "")
      end)
      |> render_representations(conn)

    Enum.map(collection, fn %{body: text} ->
      (text || "")
      |> Markdown.to_html(representations)
      |> Phoenix.HTML.raw()
    end)
  end

  @doc """
  Renders a line-by-line diff table between two Markdown sources to safe HTML.
  """
  # The NIF escapes the source text; only its own diff markup is live
  # sobelow_skip ["XSS.Raw"]
  def render_diff(old, new) do
    (old || "")
    |> Markdown.to_html_diff(new || "")
    |> Phoenix.HTML.raw()
  end

  @doc """
  Renders line diffs for a list of version structs (as prepared by
  `Philomena.Versions.for_post/1` and `for_comment/1`).
  Each version's `:difference` field is set to the rendered safe HTML diff
  from the next-older revision's body to this version's body.
  """
  def render_version_diffs(versions) do
    Enum.map(versions, fn v ->
      %{v | difference: render_diff(v.previous_body, v.body)}
    end)
  end

  # This is rendered Markdown for use on static pages
  # sobelow_skip ["XSS.Raw"]
  def render_unsafe(text, conn) do
    images = find_images(text)
    representations = render_representations(images, conn)

    text
    |> Markdown.to_html_unsafe(representations)
    |> Phoenix.HTML.raw()
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

    ids
    |> Images.list_images_by_ids()
    |> Map.new(&{&1.id, &1})
  end

  defp link_suffix(image) do
    cond do
      not is_nil(image.duplicate_id) ->
        " (merged)"

      image.hidden_from_users ->
        " (deleted)"

      not image.approved ->
        " (pending approval)"

      true ->
        ""
    end
  end

  defp render_representations(images, conn) do
    loaded_images = load_images(images)

    Map.new(images, fn group ->
      img = loaded_images[Enum.at(group, 0)]
      text = "#{Enum.at(group, 0)}#{Enum.at(group, 1)}"

      rendered =
        if img != nil do
          case group do
            [_id, "p"] when not img.hidden_from_users and img.approved ->
              Phoenix.View.render(ImageView, "_image_target.html",
                embed_display: true,
                image: img,
                size: ImageView.select_version(img, :medium),
                conn: conn
              )

            [_id, "t"] when not img.hidden_from_users and img.approved ->
              Phoenix.View.render(ImageView, "_image_target.html",
                embed_display: true,
                image: img,
                size: ImageView.select_version(img, :small),
                conn: conn
              )

            [_id, "s"] when not img.hidden_from_users and img.approved ->
              Phoenix.View.render(ImageView, "_image_target.html",
                embed_display: true,
                image: img,
                size: ImageView.select_version(img, :thumb_small),
                conn: conn
              )

            [_id, suffix] when not img.approved ->
              ">>#{img.id}#{suffix}#{link_suffix(img)}"

            [_id, ""] ->
              link(">>#{img.id}#{link_suffix(img)}", to: "/images/#{img.id}")

            [_id, suffix] when suffix in ["t", "s", "p"] ->
              link(">>#{img.id}#{suffix}#{link_suffix(img)}", to: "/images/#{img.id}")

            # This condition should never trigger, but let's leave it here just in case.
            [id, suffix] ->
              ">>#{id}#{suffix}"
          end
        else
          ">>#{text}"
        end

      string_contents =
        rendered
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      {text, string_contents}
    end)
  end
end
