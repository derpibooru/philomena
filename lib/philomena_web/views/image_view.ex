defmodule PhilomenaWeb.ImageView do
  use PhilomenaWeb, :view

  alias Philomena.Tags.Tag
  alias Philomena.Images.Thumbnailer

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
    Thumbnailer.thumbnail_versions()
    |> Map.new(fn {name, {width, height}} ->
      if image.image_width > width or image.image_height > height do
        {name, thumb_url(image, show_hidden, name)}
      else
        {name, thumb_url(image, show_hidden, :full)}
      end
    end)
    |> append_full_url(image, show_hidden)
    |> append_gif_urls(image, show_hidden)
  end

  def select_version(image, version_name) do
    Thumbnailer.thumbnail_versions()
    |> Map.new(fn {name, {width, height}} ->
      if image.image_width > width or image.image_height > height do
        {name, version_name}
      else
        {name, :full}
      end
    end)
    |> Map.get(version_name, :full)
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

  def thumb_url_size(
        %{image_aspect_ratio: ar, image_width: w, image_height: h} = image,
        show_hidden,
        name
      ) do
    {max_w, max_h} = Thumbnailer.thumbnail_versions()[name]

    if w > max_w or h > max_h do
      {thumb_url(image, show_hidden, name), thumb_dimensions(ar, max_w, max_h)}
    else
      {thumb_url(image, show_hidden, :full), {w, h}}
    end
  end

  defp thumb_dimensions(ar, w, h) when ar > w / h,
    do: {w, floor(w / ar)}

  defp thumb_dimensions(ar, _w, h),
    do: {floor(h * ar), h}

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
    filename = if short, do: image.id, else: verbose_file_name(image)

    format =
      image.image_format
      |> to_string()
      |> String.downcase()
      |> thumb_format(nil, download)

    "#{root}/#{view}/#{year}/#{month}/#{day}/#{filename}.#{format}"
  end

  defp verbose_file_name(image) do
    # Truncate filename to 150 characters, making room for the path + filename on Windows
    # https://stackoverflow.com/questions/265769/maximum-filename-length-in-ntfs-windows-xp-and-windows-vista
    file_name_slug_fragment =
      image.tags
      |> display_order()
      |> Enum.map_join("_", & &1.slug)
      |> String.to_charlist()
      |> Enum.filter(&(&1 in ?a..?z or &1 in ~c"0123456789_-+"))
      |> List.to_string()
      |> String.slice(0..150)

    "#{image.id}__#{file_name_slug_fragment}"
  end

  def image_url_root do
    Application.get_env(:philomena, :image_url_root)
  end

  def image_container_data(conn, image, size) do
    [
      image_id: image.id,
      image_tags: Jason.encode!(Enum.map(image.tags, & &1.id)),
      image_tag_aliases:
        image.tags |> Enum.flat_map(&([&1] ++ &1.aliases)) |> Enum.map_join(", ", & &1.name),
      tag_count: length(image.tags),
      score: image.score,
      faves: image.faves_count,
      upvotes: image.upvotes_count,
      downvotes: image.downvotes_count,
      comment_count: image.comments_count,
      created_at: DateTime.to_iso8601(image.created_at),
      source_url:
        if(Enum.count(image.sources) > 0, do: Enum.at(image.sources, 0).source, else: ""),
      source_urls: Jason.encode!(Enum.map(image.sources, & &1.source)),
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

  def scaled_value(%{scale_large_images: scale}), do: scale
  def scaled_value(_user), do: "true"

  def hides_images?(conn), do: can?(conn, :hide, %Philomena.Images.Image{})

  def random_button(conn, params) do
    render(PhilomenaWeb.ImageView, "_random_button.html", conn: conn, params: params)
  end

  def hidden_toggle(%{assigns: %{current_user: nil}}, _route, _params), do: nil

  def hidden_toggle(conn, route, params) do
    render(PhilomenaWeb.ImageView, "_hidden_toggle.html",
      route: route,
      params: params,
      conn: conn
    )
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
      "namespaced_tags.name":
        image.tags |> Enum.flat_map(&([&1] ++ &1.aliases)) |> Enum.map_join(", ", & &1.name),
      tag_count: length(image.tags),
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
      orig_sha512_hash: image.image_orig_sha512_hash,
      description: image.description
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

    PhilomenaQuery.Parse.Evaluator.hits?(doc, query)
  end

  def image_source_icon(nil), do: "fa fa-link"
  def image_source_icon(""), do: "fa fa-link"

  def image_source_icon(source) do
    site_domains =
      String.split(Application.get_env(:philomena, :site_domains), ",") ++
        [Application.get_env(:philomena, :cdn_host)]

    uri = URI.parse(source)

    case uri.host do
      u
      when u in [
             "twitter.com",
             "www.twitter.com",
             "mobile.twitter.com",
             "x.com",
             "mobile.x.com",
             "pbs.twimg.com",
             "twimg.com"
           ] ->
        "fab fa-twitter"

      u
      when u in [
             "deviantart.com",
             "sta.sh",
             "www.sta.sh",
             "images-wixmp-ed30a86b8c4ca887773594c2.wixmp.com",
             "wixmp-ed30a86b8c4ca887773594c2.wixmp.com",
             "api-da.wixmp.com",
             "fav.me"
           ] ->
        "fab fa-deviantart"

      u
      when u in [
             "cdn.discordapp.com",
             "discordapp.com",
             "discord.com",
             "discord.gg"
           ] ->
        "fab fa-discord"

      u when u in ["youtube.com", "www.youtube.com", "youtu.be", "m.youtube.com"] ->
        "fab fa-youtube"

      u when u in ["pillowfort.social", "www.pillowfort.social"] ->
        "fa fa-bed"

      u when u in ["vk.com", "vk.ru"] ->
        "fab fa-vk"

      u
      when u in ["artfight.net", "www.artfight.net", "newgrounds.com"] ->
        "fa fa-paintbrush"

      u when u in ["pixiv.net", "www.pixiv.net", "pixiv.me"] ->
        "fab fa-pixiv"

      u when u in ["patreon.com", "www.patreon.com"] ->
        "fab fa-patreon"

      u
      when u in [
             "ych.art",
             "cdn.ych.art",
             "ych.commishes.com",
             "commishes.com",
             "portfolio.commishes.com",
             "commishes.io"
           ] ->
        "fa fa-palette"

      u
      when u in ["ko-fi.com", "storage.ko-fi.com", "buymeacoffee.com", "www.buymeacoffee.com"] ->
        "fa fa-coffee"

      u when u in ["artstation.com", "www.artstation.com"] ->
        "fab fa-artstation"

      u when u in ["instagram.com", "www.instagram.com"] ->
        "fab fa-instagram"

      u when u in ["t.me"] ->
        "fab fa-telegram"

      u
      when u in [
             "reddit.com",
             "www.reddit.com",
             "old.reddit.com",
             "redd.it",
             "i.redd.it",
             "v.redd.it",
             "preview.redd.it"
           ] ->
        "fab fa-reddit"

      u when u in ["facebook.com", "www.facebook.com", "fb.me", "www.fb.me", "m.facebook.com"] ->
        "fab fa-facebook"

      u when u in ["tiktok.com", "www.tiktok.com"] ->
        "fab fa-tiktok"

      u
      when u in [
             "furaffinity.net",
             "furbooru.org",
             "inkbunny.net",
             "e621.net",
             "e926.net",
             "sofurry.com",
             "weasyl.com",
             "www.weasyl.com",
             "cdn.weasyl.com"
           ] ->
        "fa fa-paw"

      u
      when u in [
             "awoo.space",
             "bark.lgbt",
             "equestria.social",
             "foxy.social",
             "mastodon.art",
             "mastodon.social",
             "meow.social",
             "pawoo.net",
             "pettingzoo.co",
             "pony.social",
             "vulpine.club",
             "yiff.life",
             "socel.net",
             "octodon.social",
             "filly.social",
             "pone.social",
             "hooves.social"
           ] ->
        "fab fa-mastodon"

      u
      when u in ["tumbex.com", "www.tumbex.com", "tumblr.com", "tmblr.co"] ->
        "fab fa-tumblr"

      u when u in ["flickr.com", "www.flickr.com"] ->
        "fab fa-flickr"

      u when u in ["etsy.com", "www.etsy.com"] ->
        "fab fa-etsy"

      link ->
        cond do
          Enum.member?(site_domains, link) ->
            "favicon-home"

          String.ends_with?(link, ".tumblr.com") ->
            "fab fa-tumblr"

          String.ends_with?(link, ".deviantart.com") or String.ends_with?(link, ".deviantart.net") ->
            "fab fa-deviantart"

          String.ends_with?(link, ".furaffinity.net") or String.ends_with?(link, ".sofurry.com") or
              String.ends_with?(link, ".facdn.net") ->
            "fa fa-paw"

          String.ends_with?(link, ".userapi.com") or String.ends_with?(link, ".vk.me") ->
            "fab fa-vk"

          String.ends_with?(link, ".patreonusercontent.com") ->
            "fab fa-patreon"

          String.ends_with?(link, ".discordapp.net") ->
            "fab fa-discord"

          String.ends_with?(link, ".ytimg.com") ->
            "fab fa-youtube"

          String.ends_with?(link, ".fbcdn.net") ->
            "fab fa-facebook"

          String.ends_with?(link, ".newgrounds.com") or String.ends_with?(link, ".ngfiles.com") ->
            "fa fa-paintbrush"

          String.ends_with?(link, ".apple.com") ->
            "fab fa-apple"

          String.ends_with?(link, ".staticflickr.com") ->
            "fab fa-flickr"

          String.ends_with?(link, ".etsystatic.com") ->
            "fab fa-etsy"

          true ->
            "fa fa-link"
        end
    end
  end
end
