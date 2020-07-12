defmodule PhilomenaWeb.ImageView do
  use PhilomenaWeb, :view

  alias Philomena.Tags.Tag

  def show_vote_counts?(%{hide_vote_counts: true}), do: false
  def show_vote_counts?(_user), do: true

  def title_text(image) do
    tags = Tag.display_order(image.tags) |> Enum.map_join(", ", & &1.name)

    "Size: #{image.image_width}x#{image.image_height} | Tagged: #{tags}"
  end

  # this is a bit ridiculous
  def render_intent(_conn, %{thumbnails_generated: false}, _size), do: :not_rendered

  def render_intent(conn, image, size) do
    uris = thumb_urls(image, can?(conn, :show, image))
    vid? = image.image_mime_type == "video/webm"
    gif? = image.image_mime_type == "image/gif"
    alt = title_text(image)

    hidpi? = conn.cookies["hidpi"] == "true"
    webm? = conn.cookies["webm"] == "true"
    use_gif? = vid? and not webm? and size in ~W(thumb thumb_small thumb_tiny)a
    filtered? = filter_or_spoiler_hits?(conn, image)

    cond do
      filtered? and vid? ->
        {:filtered_video, alt}

      filtered? and not vid? ->
        {:filtered_image, alt}

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
    |> append_full_url(image, show_hidden)
    |> append_gif_urls(image, show_hidden)
  end

  defp append_full_url(urls, %{hidden_from_users: false} = image, _show_hidden),
    do: Map.put(urls, :full, pretty_url(image, true, false))

  defp append_full_url(urls, %{hidden_from_users: true} = image, true),
    do: Map.put(urls, :full, thumb_url(image, true, :full))

  defp append_full_url(urls, _image, _show_hidden),
    do: urls

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
      |> to_string()
      |> String.downcase()
      |> thumb_format(name, false)

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
      |> to_string()
      |> String.downcase()
      |> thumb_format(nil, download)

    "#{root}/#{view}/#{year}/#{month}/#{day}/#{filename}.#{format}"
  end

  def image_url_root do
    Application.get_env(:philomena, :image_url_root)
  end

  def image_container_data(conn, image, size) do
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
      uris: Jason.encode!(thumb_urls(image, can?(conn, :show, image))),
      width: image.image_width,
      height: image.image_height,
      aspect_ratio: image.image_aspect_ratio,
      size: size
    ]
  end

  def image_container(conn, image, size, block) do
    content_tag(:div, block.(),
      class: "image-container #{size}",
      data: image_container_data(conn, image, size)
    )
  end

  def display_order(tags) do
    Tag.display_order(tags)
  end

  def username(%{name: name}), do: name
  def username(_user), do: nil

  def scope(conn), do: PhilomenaWeb.ImageScope.scope(conn)

  def anonymous_by_default?(conn) do
    conn.assigns.current_user.anonymous_by_default
  end

  def info_row(_conn, []), do: []

  def info_row(conn, [{tag, description, dnp_entries}]) do
    render(PhilomenaWeb.TagView, "_tag_info_row.html",
      conn: conn,
      tag: tag,
      body: description,
      dnp_entries: dnp_entries
    )
  end

  def info_row(conn, tags) do
    render(PhilomenaWeb.TagView, "_tags_row.html", conn: conn, tags: tags)
  end

  def quick_tag(conn) do
    if can?(conn, :batch_update, Tag) do
      render(PhilomenaWeb.ImageView, "_quick_tag.html", conn: conn)
    end
  end

  def deleter(%{deleter: %{name: name}}), do: name
  def deleter(_image), do: "System"

  def scaled_value(%{scale_large_images: false}), do: "false"
  def scaled_value(_user), do: "true"

  def hides_images?(conn), do: can?(conn, :hide, %Philomena.Images.Image{})

  def random_button(conn, params) do
    render(PhilomenaWeb.ImageView, "_random_button.html", conn: conn, params: params)
  end

  def hidden_toggle(%{assigns: %{current_user: nil}}, _route, _params), do: nil

  def hidden_toggle(conn, route, params) do
    render(PhilomenaWeb.ImageView, "_hidden_toggle.html", route: route, params: params, conn: conn)
  end

  def deleted_toggle(conn, route, params) do
    if hides_images?(conn) do
      render(PhilomenaWeb.ImageView, "_deleted_toggle.html",
        route: route,
        params: params,
        conn: conn
      )
    end
  end

  defp thumb_format("svg", _name, false), do: "png"
  defp thumb_format(_, :rendered, _download), do: "png"
  defp thumb_format(format, _name, _download), do: format

  def image_filter_data(image) do
    %{
      id: image.id,
      "namespaced_tags.name": String.split(image.tag_list_plus_alias_cache || "", ", "),
      score: image.score,
      faves: image.faves_count,
      upvotes: image.upvotes_count,
      downvotes: image.downvotes_count,
      comment_count: image.comments_count,
      created_at: image.created_at,
      first_seen_at: image.first_seen_at,
      source_url: image.source_url,
      width: image.image_width,
      height: image.image_height,
      aspect_ratio: image.image_aspect_ratio,
      sha512_hash: image.image_sha512_hash,
      orig_sha512_hash: image.image_orig_sha512_hash
    }
  end

  def filter_or_spoiler_hits?(conn, image) do
    tag_filter_or_spoiler_hits?(conn, image) or complex_filter_or_spoiler_hits?(conn, image)
  end

  defp tag_filter_or_spoiler_hits?(conn, image) do
    filter = conn.assigns.current_filter
    filtered_tag_ids = MapSet.new(filter.spoilered_tag_ids ++ filter.hidden_tag_ids)
    image_tag_ids = MapSet.new(image.tags, & &1.id)

    MapSet.size(MapSet.intersection(filtered_tag_ids, image_tag_ids)) > 0
  end

  defp complex_filter_or_spoiler_hits?(conn, image) do
    doc = image_filter_data(image)
    complex_filter = conn.assigns.compiled_complex_filter
    complex_spoiler = conn.assigns.compiled_complex_spoiler

    query = %{
      bool: %{
        should: [complex_filter, complex_spoiler]
      }
    }

    Philomena.Search.Evaluator.hits?(doc, query)
  end
end
