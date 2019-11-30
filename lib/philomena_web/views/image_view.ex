defmodule PhilomenaWeb.ImageView do
  use PhilomenaWeb, :view

  alias Philomena.Tags.Tag

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
  end

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

  defp thumb_format("svg"), do: "png"
  defp thumb_format(format), do: format
end
