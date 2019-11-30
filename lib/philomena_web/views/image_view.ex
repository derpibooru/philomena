defmodule PhilomenaWeb.ImageView do
  use PhilomenaWeb, :view

  alias Philomena.Tags.Tag

  def show_vote_counts?(%{hide_vote_counts: true}), do: false
  def show_vote_counts?(_user), do: true

  # this is a bit ridculous
  def render_intent(_conn, %{thumbnails_generated: false}, _size), do: :not_rendered
  def render_intent(conn, image, size) do
    uris = thumb_urls(image, false)
    vid? = image.image_mime_type == "video/webm"
    gif? = image.image_mime_type == "image/gif"
    tags = Tag.display_order(image.tags) |> Enum.map_join(", ", & &1.name)
    alt = "Size: #{image.image_width}x#{image.image_height} | Tagged: #{tags}"

    hidpi? = conn.cookies["hidpi"] == "true"
    webm? = conn.cookies["webm"] == "true"
    use_gif? = vid? and not webm? and size in ~W(thumb thumb_small thumb_tiny)a

    cond do
      hidpi? and not (gif? or vid?) ->
        {:hidpi, uris[size], uris[:medium], alt}

      not vid? or use_gif? ->
        {:image, String.replace(uris[size], ".webm", ".gif"), alt}

      true ->
        {:video, uris[size], String.replace(uris[size], ".webm", ".mp4"), alt}
    end
  end

  def thumb_urls(image, show_hidden) do
    %{
      thumb_tiny: thumb_url(image, show_hidden, :thumb_tiny),
      thumb_small: thumb_url(image, show_hidden, :thumb_small),
      thumb: thumb_url(image, show_hidden, :thumb),
      small: thumb_url(image, show_hidden, :small),
      medium: thumb_url(image, show_hidden, :medium),
      large: thumb_url(image, show_hidden, :large),
      tall: thumb_url(image, show_hidden, :tall),
      full: pretty_url(image, true, false)
    }
    |> append_gif_urls(image, show_hidden)
  end

  defp append_gif_urls(urls, %{image_mime_type: "image/gif"} = image, show_hidden) do
    full_url = thumb_url(image, show_hidden, :full)

    Map.merge(
      urls,
      %{
        webm: String.replace(full_url, ".gif", ".webm"),
        mp4: String.replace(full_url, ".gif", ".mp4")
      }
    )
  end
  defp append_gif_urls(urls, _image, _show_hidden), do: urls

  def thumb_url(image, show_hidden, name) do
    %{year: year, month: month, day: day} = image.created_at
    deleted = image.hidden_from_users
    root = image_url_root()
    format =
      image.image_format
      |> String.downcase()
      |> thumb_format()

    id_fragment =
      if deleted and show_hidden do
        "#{image.id}-#{image.hidden_image_key}"
      else
        "#{image.id}"
      end

    "#{root}/#{year}/#{month}/#{day}/#{id_fragment}/#{name}.#{format}"
  end

  def pretty_url(image, short, download) do
    %{year: year, month: month, day: day} = image.created_at
    root = image_url_root()

    view = if download, do: "download", else: "view"
    filename = if short, do: image.id, else: image.file_name_cache
    format =
      image.image_format
      |> String.downcase()
      |> thumb_format()

    "#{root}/#{view}/#{year}/#{month}/#{day}/#{filename}.#{format}"
  end

  def image_url_root do
    Application.get_env(:philomena, :image_url_root)
  end

  def image_container_data(image, size) do
    [
      image_id: image.id,
      image_tags: Jason.encode!(Enum.map(image.tags, & &1.id)),
      image_tag_aliases: image.tag_list_plus_alias_cache,
      score: image.score,
      faves: image.faves_count,
      upvotes: image.upvotes_count,
      downvotes: image.downvotes_count,
      comment_count: image.comments_count,
      created_at: NaiveDateTime.to_iso8601(image.created_at),
      source_url: image.source_url,
      uris: Jason.encode!(thumb_urls(image, false)),
      width: image.image_width,
      height: image.image_height,
      aspect_ratio: image.image_aspect_ratio,
      size: size
    ]
  end

  def image_container(image, size, block) do
    content_tag(:div, block.(), class: "image-container #{size}", data: image_container_data(image, size))
  end

  def display_order(tags) do
    Tag.display_order(tags)
  end

  def scope(conn), do: Philomena.ImageScope.scope(conn)

  def anonymous_by_default?(conn) do
    conn.assigns.current_user.anonymous_by_default
  end

  defp thumb_format("svg"), do: "png"
  defp thumb_format(format), do: format
end
