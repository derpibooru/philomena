defmodule PhilomenaWeb.TextileRenderer do
  alias Philomena.Textile.Parser
  alias Philomena.Images.Image
  alias Philomena.Repo
  import Phoenix.HTML
  import Phoenix.HTML.Link
  import Ecto.Query

  # Kill bogus compile time dependency on ImageView
  @image_view Module.concat(["PhilomenaWeb.ImageView"])

  def render_one(post, conn) do
    hd(render_collection([post], conn))
  end

  def render_collection(posts, conn) do
    opts = %{image_transform: &Camo.Image.image_url/1}
    parsed = Enum.map(posts, &Parser.parse(opts, &1.body))

    images =
      parsed
      |> Enum.flat_map(fn tree ->
        tree
        |> Enum.flat_map(fn
          {:text, text} ->
            [text]

          _ ->
            []
        end)
      end)
      |> find_images

    parsed
    |> Enum.map(fn tree ->
      tree
      |> Enum.map(fn
        {:text, text} ->
          text
          |> replacement_entities()
          |> replacement_images(conn, images)

        {_k, markup} ->
          markup
      end)
      |> Enum.join()
    end)
  end

  defp replacement_entities(t) do
    t
    |> String.replace("-&gt;", "&rarr;")
    |> String.replace("--", "&mdash;")
    |> String.replace("...", "&hellip;")
    |> String.replace(~r|(\s)-(\s)|, "\\1&mdash;\\2")
    |> String.replace("(tm)", "&trade;")
    |> String.replace("(c)", "&copy;")
    |> String.replace("(r)", "&reg;")
    |> String.replace("&apos;", "&rsquo;")
  end

  defp replacement_images(t, conn, images) do
    t
    |> String.replace(~r|&gt;&gt;(\d+)([pts])?|, fn match ->
      # Stupid, but the method doesn't give us capture group information
      match_data = Regex.run(~r|&gt;&gt;(\d+)([pts])?|, match, capture: :all_but_first)
      [image_id | rest] = match_data
      image = images[String.to_integer(image_id)]

      case [image | rest] do
        [nil, _] ->
          match

        [nil] ->
          match

        [image, "p"] when not image.hidden_from_users ->
          Phoenix.View.render(@image_view, "_image_target.html",
            image: image,
            size: :medium,
            conn: conn
          )
          |> safe_to_string()

        [image, "t"] when not image.hidden_from_users ->
          Phoenix.View.render(@image_view, "_image_target.html",
            image: image,
            size: :small,
            conn: conn
          )
          |> safe_to_string()

        [image, "s"] when not image.hidden_from_users ->
          Phoenix.View.render(@image_view, "_image_target.html",
            image: image,
            size: :thumb_small,
            conn: conn
          )
          |> safe_to_string()

        [image, suffix] when suffix in ["p", "t", "s"] ->
          link(">>#{image.id}#{suffix}#{link_postfix(image)}", to: "/#{image.id}")
          |> safe_to_string()

        [image] ->
          link(">>#{image.id}#{link_postfix(image)}", to: "/#{image.id}")
          |> safe_to_string()
      end
    end)
  end

  defp find_images(text_segments) do
    text_segments
    |> Enum.flat_map(fn t ->
      Regex.scan(~r|&gt;&gt;(\d+)|, t, capture: :all_but_first)
      |> Enum.map(fn [first] -> String.to_integer(first) end)
      |> Enum.filter(&(&1 < 2_147_483_647))
    end)
    |> load_images()
  end

  defp load_images([]), do: %{}

  defp load_images(ids) do
    Image
    |> where([i], i.id in ^ids)
    |> preload(tags: :aliases)
    |> Repo.all()
    |> Map.new(&{&1.id, &1})
  end

  defp link_postfix(image) do
    cond do
      not is_nil(image.duplicate_id) ->
        " (merged)"

      image.hidden_from_users ->
        " (deleted)"

      true ->
        ""
    end
  end
end
