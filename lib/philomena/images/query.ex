defmodule Philomena.Images.Query do
  import Philomena.Search.Parser
  import Philomena.Search.String

  defparser("anonymous",
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
  )

  defparser("user",
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
        %{user: %{id: id}}, "faves" ->
          %{term: %{favourited_by_user_ids: id}}

        %{user: %{id: id}}, "upvotes" ->
          %{term: %{upvoter_ids: id}}

        %{user: %{id: id}}, "downvotes" ->
          %{term: %{downvoter_ids: id}}

        %{watch: true}, "watched" ->
          raise ArgumentError, "Recursive watchlists are not allowed."

        %{user: user} = ctx, "watched" ->
          ctx = Map.merge(ctx, %{watch: true})

          tag_include = %{terms: %{tag_ids: user.watched_tag_ids}}

          {:ok, include_query} =
            Philomena.Images.Query.user_parser(ctx, user.watched_images_query |> normalize())

          {:ok, exclude_query} =
            Philomena.Images.Query.user_parser(
              ctx,
              user.watched_images_exclude_query |> normalize()
            )

          should = [tag_include, include_query]
          must_not = [exclude_query]

          must_not =
            if user.no_spoilered_in_watched do
              user = user |> Repo.preload(:current_filter)

              tag_exclude = %{terms: %{tag_ids: user.current_filter.spoilered_tag_ids}}

              {:ok, spoiler_query} =
                Philomena.Images.Query.user_parser(
                  ctx,
                  user.current_filter.spoilered_complex_str |> normalize()
                )

              [tag_exclude, spoiler_query | must_not]
            else
              must_not
            end

          %{bool: %{should: should, must_not: must_not}}
      end
    },
    aliases: %{
      "faved_by" => "favourited_by_users",
      "faved_by_id" => "favourited_by_user_ids"
    },
    default: "namespaced_tags.name"
  )

  defparser("moderator",
    int:
      ~W(id width height comment_count score upvotes downvotes faves uploader_id faved_by_id upvoted_by_id downvoted_by_id tag_count true_uploader_id hidden_by_id deleted_by_user-id),
    float: ~W(aspect_ratio wilson_score),
    date: ~W(created_at updated_at first_seen_at),
    literal:
      ~W(faved_by orig_sha512_hash sha512_hash uploader source_url original_format fingerprint upvoted_by downvoted_by true_uploader hidden_by deleted_by_user),
    ngram: ~W(description deletion_reason),
    ip: ~W(ip),
    bool: ~W(deleted),
    custom: ~W(gallery_id my),
    transforms: %{
      "gallery_id" => fn _ctx, value ->
        %{nested: %{path: :galleries, query: %{term: %{"galleries.id" => value}}}}
      end,
      "my" => fn
        %{user: %{id: id}}, "faves" ->
          %{term: %{favourited_by_user_ids: id}}

        %{user: %{id: id}}, "upvotes" ->
          %{term: %{upvoter_ids: id}}

        %{user: %{id: id}}, "downvotes" ->
          %{term: %{downvoter_ids: id}}

        %{watch: true}, "watched" ->
          raise ArgumentError, "Recursive watchlists are not allowed."

        %{user: user} = ctx, "watched" ->
          ctx = Map.merge(ctx, %{watch: true})

          tag_include = %{terms: %{tag_ids: user.watched_tag_ids}}

          {:ok, include_query} =
            Philomena.Images.Query.moderator_parser(ctx, user.watched_images_query |> normalize())

          {:ok, exclude_query} =
            Philomena.Images.Query.moderator_parser(
              ctx,
              user.watched_images_exclude_query |> normalize()
            )

          should = [tag_include, include_query]
          must_not = [exclude_query]

          must_not =
            if user.no_spoilered_in_watched do
              user = user |> Repo.preload(:current_filter)

              tag_exclude = %{terms: %{tag_ids: user.current_filter.spoilered_tag_ids}}

              {:ok, spoiler_query} =
                Philomena.Images.Query.moderator_parser(
                  ctx,
                  user.current_filter.spoilered_complex_str |> normalize()
                )

              [tag_exclude, spoiler_query | must_not]
            else
              must_not
            end

          %{bool: %{should: should, must_not: must_not}}
      end
    },
    aliases: %{
      "faved_by" => "favourited_by_users",
      "upvoted_by" => "upvoters",
      "downvoted_by" => "downvoters",
      "faved_by_id" => "favourited_by_user_ids",
      "upvoted_by_id" => "upvoter_ids",
      "downvoted_by_id" => "downvoter_ids",
      "hidden_by" => "hidden_by_users",
      "hidden_by_id" => "hidden_by_user_ids",
      "deleted" => "hidden_from_users"
    },
    default: "namespaced_tags.name"
  )

  def compile(user, query_string, watch \\ false) do
    query_string = query_string || ""

    case user do
      nil ->
        anonymous_parser(%{user: nil, watch: watch}, query_string)

      %{role: role} when role in ~W(user assistant) ->
        user_parser(%{user: user, watch: watch}, query_string)

      %{role: role} when role in ~W(moderator admin) ->
        moderator_parser(%{user: user, watch: watch}, query_string)

      _ ->
        raise ArgumentError, "Unknown user role."
    end
  end
end
