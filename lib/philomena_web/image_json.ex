defmodule PhilomenaWeb.ImageJson do
  alias PhilomenaWeb.ImageView

  def as_json(_conn, %{hidden_from_users: true, duplicate_id: duplicate_id} = image)
      when not is_nil(duplicate_id) do
    %{
      id: image.id,
      created_at: image.created_at,
      updated_at: image.updated_at,
      first_seen_at: image.first_seen_at,
      duplicate_of: image.duplicate_id,
      deletion_reason: nil,
      hidden_from_users: true
    }
  end

  def as_json(_conn, %{hidden_from_users: true} = image) do
    %{
      id: image.id,
      created_at: image.created_at,
      updated_at: image.updated_at,
      first_seen_at: image.first_seen_at,
      deletion_reason: image.deletion_reason,
      duplicate_of: nil,
      hidden_from_users: true
    }
  end

  def as_json(conn, %{hidden_from_users: false} = image) do
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
      intensities: intensities(image),
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
      processed: image.processed,
      deletion_reason: nil,
      duplicate_of: nil,
      hidden_from_users: false
    }
  end

  defp intensities(%{intensity: %{nw: nw, ne: ne, sw: sw, se: se}}),
    do: %{nw: nw, ne: ne, sw: sw, se: se}

  defp intensities(_), do: nil
end
