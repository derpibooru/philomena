defmodule PhilomenaWeb.ImageJson do
  alias PhilomenaWeb.ImageView

  def as_json(conn, image) do
    %{
      id: image.id,
      created_at: image.created_at,
      updated_at: image.updated_at,
      first_seen_at: image.first_seen_at,
      width: image.image_width,
      height: image.image_height,
      mime_type: image.image_mime_type,
      format: image.image_format,
      aspect_ratio: image.image_aspect_ratio,
      name: image.image_name,
      sha512_hash: image.image_sha512_hash,
      orig_sha512_hash: image.image_orig_sha512_hash,
      tags: Enum.map(image.tags, & &1.name),
      tag_ids: Enum.map(image.tags, & &1.id),
      uploader: if(!!image.user and !image.anonymous, do: image.user.name),
      uploader_id: if(!!image.user and !image.anonymous, do: image.user.id),
      wilson_score: Philomena.Images.ElasticsearchIndex.wilson_score(image),
      score: image.score,
      upvotes: image.upvotes_count,
      downvotes: image.downvotes_count,
      faves: image.faves_count,
      comment_count: image.comments_count,
      tag_count: length(image.tags),
      description: image.description,
      source_url: image.source_url,
      view_url: ImageView.pretty_url(image, false, false),
      representations: ImageView.thumb_urls(image, false),
      spoilered: ImageView.filter_or_spoiler_hits?(conn, image),
      thumbnails_generated: image.thumbnails_generated,
      processed: image.processed
    }
  end
end
