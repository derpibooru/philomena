defmodule Philomena.Images.Query do
  import Philomena.Search.Parser

  defparser "anonymous",
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
    default: "namespaced_tags.name"

  defparser "user",
    int:
      ~W(id width height comment_count score upvotes downvotes faves uploader_id faved_by_id tag_count),
    float: ~W(aspect_ratio wilson_score),
    date: ~W(created_at updated_at first_seen_at),
    literal: ~W(faved_by orig_sha512_hash sha512_hash uploader source_url original_format),
    ngram: ~W(description),
    custom: ~W(gallery_id my),
    transforms: %{
      "gallery_id" => fn _ctx, value ->
        %{nested: %{path: :galleries, query: %{term: %{"galleries.id" => value}}}}
      end,
      "my" => fn
        %{user: %{id: id}}, "faves" -> %{term: %{favourited_by_user_ids: id}}
        %{user: %{id: id}}, "upvotes" -> %{term: %{upvoter_ids: id}}
        %{user: %{id: id}}, "downvotes" -> %{term: %{downvoter_ids: id}}
        %{user: _u}, "watched" ->
          %{query: %{match_all: %{}}} # todo
      end
    },
    aliases: %{
      "faved_by" => "favourited_by_users",
      "faved_by_id" => "favourited_by_user_ids"
    },
    default: "namespaced_tags.name"

  defparser "moderator",
    int:
      ~W(id width height comment_count score upvotes downvotes faves uploader_id faved_by_id upvoted_by_id downvoted_by_id tag_count true_uploader_id hidden_by_id deleted_by_user-id),
    float: ~W(aspect_ratio wilson_score),
    date: ~W(created_at updated_at first_seen_at),
    literal: ~W(faved_by orig_sha512_hash sha512_hash uploader source_url original_format fingerprint upvoted_by downvoted_by true_uploader hidden_by deleted_by_user),
    ngram: ~W(description deletion_reason),
    ip: ~W(ip),
    bool: ~W(deleted),
    custom: ~W(gallery_id my),
    transforms: %{
      "gallery_id" => fn _ctx, value ->
        %{nested: %{path: :galleries, query: %{term: %{"galleries.id" => value}}}}
      end,
      "my" => fn
        %{user: %{id: id}}, "faves" -> %{term: %{favourited_by_user_ids: id}}
        %{user: %{id: id}}, "upvotes" -> %{term: %{upvoter_ids: id}}
        %{user: %{id: id}}, "downvotes" -> %{term: %{downvoter_ids: id}}
        %{user: _u}, "watched" ->
          %{query: %{match_all: %{}}} # todo
      end
    },
    aliases: %{
      "faved_by" =>        "favourited_by_users",
      "upvoted_by" =>      "upvoters",
      "downvoted_by" =>    "downvoters",
      "faved_by_id" =>     "favourited_by_user_ids",
      "upvoted_by_id" =>   "upvoter_ids",
      "downvoted_by_id" => "downvoter_ids",
      "hidden_by" =>       "hidden_by_users",
      "hidden_by_id" =>    "hidden_by_user_ids",
      "deleted" =>         "hidden_from_users"
    },
    default: "namespaced_tags.name"
end
