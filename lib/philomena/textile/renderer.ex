defmodule Philomena.Textile.Renderer do
  alias Textile.Parser
  alias Philomena.Images.Image
  alias Philomena.Repo
  import Phoenix.HTML
  import Phoenix.HTML.Link
  import Ecto.Query

  @parser %Parser{
    image_transform: &Camo.Image.image_url/1
  }

  def render_one(post) do
    hd(render_collection([post]))
  end

  def render_collection(posts) do
    parsed =
      posts
      |> Enum.map(fn post ->
        Parser.parse(@parser, post.body)
      end)

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
          |> replacement_images(images)

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
    |> String.replace("(tm)", "&tm;")
    |> String.replace("(c)", "&copy;")
    |> String.replace("(r)", "&reg;")
    |> String.replace("&apos;", "&rsquo;")
  end

  defp replacement_images(t, images) do
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

        [image, "p"] ->
          Phoenix.View.render(PhilomenaWeb.ImageView, "_image_container.html", image: image, size: :medium)
          |> safe_to_string()

        [image, "t"] ->
          Phoenix.View.render(PhilomenaWeb.ImageView, "_image_container.html", image: image, size: :small)
          |> safe_to_string()

        [image, "s"] ->
          Phoenix.View.render(PhilomenaWeb.ImageView, "_image_container.html", image: image, size: :thumb_small)
          |> safe_to_string()

        [image] ->
          link(">>#{image.id}", to: "/#{image.id}")
          |> safe_to_string()
      end
    end)
  end

  defp find_images(text_segments) do
    image_ids =
      text_segments
      |> Enum.flat_map(fn t ->
        Regex.scan(~r|&gt;&gt;(\d+)|, t, capture: :all_but_first)
        |> Enum.map(fn [first] -> String.to_integer(first) end)
      end)

    Image
    |> where([i], i.id in ^image_ids)
    |> where([i], i.hidden_from_users == false)
    |> preload(:tags)
    |> Repo.all()
    |> Map.new(fn image -> {image.id, image} end)
  end
end