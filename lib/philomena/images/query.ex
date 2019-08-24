defmodule Philomena.Images.Query do
  use Philomena.Search.Lexer,
    int_fields: ~W(id width height comment_count score upvotes downvotes faves uploader_id faved_by_id tag_count),
    float_fields: ~W(aspect_ratio wilson_score),
    date_fields: ~W(created_at updated_at first_seen_at),
    literal_fields: ~W(namespaced_tags.name faved_by orig_sha512_hash sha512_hash uploader source_url original_format),
    ngram_fields: ~W(description)
end