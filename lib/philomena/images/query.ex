defmodule Philomena.Images.Query do
  alias PhilomenaQuery.Parse.Parser
  alias Philomena.Repo

  defp gallery_id_transform(_ctx, value) do
    case Integer.parse(value) do
      {value, ""} when value >= 0 ->
        {:ok, %{nested: %{path: :galleries, query: %{term: %{"galleries.id" => value}}}}}

      _error ->
        {:error, "Invalid gallery `#{value}'."}
    end
  end

  defp user_my_transform(%{user: %{id: id}}, "faves"),
    do: {:ok, %{term: %{favourited_by_user_ids: id}}}

  defp user_my_transform(%{user: %{id: id}}, "upvotes"),
    do: {:ok, %{term: %{upvoter_ids: id}}}

  defp user_my_transform(%{user: %{id: id}}, "downvotes"),
    do: {:ok, %{term: %{downvoter_ids: id}}}

  defp user_my_transform(%{user: %{id: id}}, "uploads"),
    do: {:ok, %{term: %{true_uploader_id: id}}}

  defp user_my_transform(%{user: %{id: id}}, "hidden"),
    do: {:ok, %{term: %{hidden_by_user_ids: id}}}

  defp user_my_transform(%{watch: true}, "watched"),
    do: {:error, "Recursive watchlists are not allowed."}

  defp user_my_transform(%{user: user} = ctx, "watched") do
    ctx = Map.merge(ctx, %{watch: true})

    tag_include = %{terms: %{tag_ids: user.watched_tag_ids}}

    include_query = invalid_filter_guard(ctx, user.watched_images_query_str)
    exclude_query = invalid_filter_guard(ctx, user.watched_images_exclude_str)

    should = [tag_include, include_query]
    must_not = [exclude_query]

    must_not =
      if user.no_spoilered_in_watched do
        user = user |> Repo.preload(:current_filter)

        tag_exclude = %{terms: %{tag_ids: user.current_filter.spoilered_tag_ids}}
        spoiler_query = invalid_filter_guard(ctx, user.current_filter.spoilered_complex_str)

        [tag_exclude, spoiler_query | must_not]
      else
        must_not
      end

    {:ok, %{bool: %{should: should, must_not: must_not}}}
  end

  defp user_my_transform(_ctx, _value),
    do: {:error, "Unknown `my' value."}

  defp invalid_filter_guard(ctx, search_string) do
    case parse(user_fields(), ctx, PhilomenaQuery.Parse.String.normalize(search_string)) do
      {:ok, query} -> query
      _error -> %{match_all: %{}}
    end
  end

  defp tag_count_fields do
    [
      "body_type_tag_count",
      "error_tag_count",
      "character_tag_count",
      "content_fanmade_tag_count",
      "content_official_tag_count",
      "oc_tag_count",
      "origin_tag_count",
      "rating_tag_count",
      "species_tag_count",
      "spoiler_tag_count"
    ]
  end

  defp anonymous_fields do
    [
      int_fields:
        ~W(id width height score upvotes downvotes faves uploader_id faved_by_id pixels size orig_size comment_count source_count tag_count) ++
          tag_count_fields(),
      float_fields: ~W(aspect_ratio wilson_score duration),
      date_fields: ~W(created_at updated_at first_seen_at),
      literal_fields:
        ~W(faved_by orig_sha512_hash sha512_hash uploader source_url original_format mime_type file_name),
      bool_fields: ~W(animated processed thumbnails_generated),
      ngram_fields: ~W(description),
      custom_fields: ~W(gallery_id),
      default_field: {"namespaced_tags.name", :term},
      transforms: %{"gallery_id" => &gallery_id_transform/2},
      aliases: %{
        "faved_by" => "favourited_by_users",
        "faved_by_id" => "favourited_by_user_ids"
      },
      no_downcase_fields: ~W(file_name)
    ]
  end

  defp user_fields do
    fields = anonymous_fields()

    Keyword.merge(fields,
      custom_fields: fields[:custom_fields] ++ ~W(my),
      transforms: Map.merge(fields[:transforms], %{"my" => &user_my_transform/2})
    )
  end

  defp moderator_fields do
    fields = user_fields()

    Keyword.merge(fields,
      int_fields:
        fields[:int_fields] ++
          ~W(upvoted_by_id downvoted_by_id true_uploader_id hidden_by_id deleted_by_user_id),
      literal_fields:
        fields[:literal_fields] ++
          ~W(fingerprint upvoted_by downvoted_by true_uploader hidden_by deleted_by_user),
      ngram_fields: fields[:ngram_fields] ++ ~W(deletion_reason),
      ip_fields: ~W(ip),
      bool_fields: fields[:bool_fields] ++ ~W(deleted),
      aliases:
        Map.merge(fields[:aliases], %{
          "upvoted_by" => "upvoters",
          "downvoted_by" => "downvoters",
          "upvoted_by_id" => "upvoter_ids",
          "downvoted_by_id" => "downvoter_ids",
          "hidden_by" => "hidden_by_users",
          "hidden_by_id" => "hidden_by_user_ids",
          "deleted" => "hidden_from_users"
        })
    )
  end

  defp parse(fields, context, query_string) do
    fields
    |> Parser.new()
    |> Parser.parse(query_string, context)
  end

  def compile(query_string, opts \\ []) do
    user = Keyword.get(opts, :user)
    watch = Keyword.get(opts, :watch, false)

    case user do
      nil ->
        parse(anonymous_fields(), %{user: nil, watch: watch}, query_string)

      %{role: role} when role in ~W(user assistant) ->
        parse(user_fields(), %{user: user, watch: watch}, query_string)

      %{role: role} when role in ~W(moderator admin) ->
        parse(moderator_fields(), %{user: user, watch: watch}, query_string)

      _ ->
        raise ArgumentError, "Unknown user role."
    end
  end
end
