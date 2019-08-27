defmodule Philomena.Images.Query do
  use Philomena.Search.Parser,
    int:
      ~W(id width height comment_count score upvotes downvotes faves uploader_id faved_by_id tag_count),
    float: ~W(aspect_ratio wilson_score),
    date: ~W(created_at updated_at first_seen_at),
    literal: ~W(faved_by orig_sha512_hash sha512_hash uploader source_url original_format),
    ngram: ~W(description),
    custom: ~W(gallery_id),
    transforms: %{
      "gallery_id" => fn _ctx, value ->
        %{nested: %{path: :galleries, query: %{term: %{"galleries.id" => value}}}}
      end
    },
    aliases: %{
      "faved_by" => "favourited_by_users",
      "faved_by_id" => "favourited_by_user_ids"
    },
    default: "namespaced_tags.name",
    name: "anonymous"
end
