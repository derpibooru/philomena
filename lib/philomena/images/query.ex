defmodule Philomena.Images.Query do
  alias Search.Parser
  alias Philomena.Repo

  def gallery_id_transform(_ctx, value),
    do: {:ok, %{nested: %{path: :galleries, query: %{term: %{"galleries.id" => value}}}}}

  def user_my_transform(%{user: %{id: id}}, "faves"),
    do: {:ok, %{term: %{favourited_by_user_ids: id}}}

  def user_my_transform(%{user: %{id: id}}, "upvotes"),
    do: {:ok, %{term: %{upvoter_ids: id}}}

  def user_my_transform(%{user: %{id: id}}, "downvotes"),
    do: {:ok, %{term: %{downvoter_ids: id}}}

  def user_my_transform(%{watch: true}, "watched"),
    do: {:error, "Recursive watchlists are not allowed."}

  def user_my_transform(%{user: user} = ctx, "watched") do
    ctx = Map.merge(ctx, %{watch: true})

    tag_include = %{terms: %{tag_ids: user.watched_tag_ids}}

    {:ok, include_query} =
      Philomena.Images.Query.parse_user(ctx, user.watched_images_query_str |> Search.String.normalize())

    {:ok, exclude_query} =
      Philomena.Images.Query.parse_user(
        ctx,
        user.watched_images_exclude_str |> Search.String.normalize()
      )

    should = [tag_include, include_query]
    must_not = [exclude_query]

    must_not =
      if user.no_spoilered_in_watched do
        user = user |> Repo.preload(:current_filter)

        tag_exclude = %{terms: %{tag_ids: user.current_filter.spoilered_tag_ids}}

        {:ok, spoiler_query} =
          Philomena.Images.Query.parse_user(
            ctx,
            user.current_filter.spoilered_complex_str |> Search.String.normalize()
          )

        [tag_exclude, spoiler_query | must_not]
      else
        must_not
      end

    %{bool: %{should: should, must_not: must_not}}
  end

  def user_my_transform(_ctx, _value),
    do: {:error, "Unknown `my' value."}


  int_fields         = ~W(id width height comment_count score upvotes downvotes faves uploader_id faved_by_id tag_count)
  float_fields       = ~W(aspect_ratio wilson_score)
  date_fields        = ~W(created_at updated_at first_seen_at)
  literal_fields     = ~W(faved_by orig_sha512_hash sha512_hash uploader source_url original_format)
  ngram_fields       = ~W(description)
  custom_fields      = ~W(gallery_id)
  default_field      = "namespaced_tags.name"
  transforms         = %{
    "gallery_id" => &Philomena.Images.Query.gallery_id_transform/2
  }
  aliases            = %{
    "faved_by" => "favourited_by_users",
    "faved_by_id" => "favourited_by_user_ids"
  }


  user_custom        = custom_fields ++ ~W(my)
  user_transforms    = Map.merge(transforms, %{
    "my" => &Philomena.Images.Query.user_my_transform/2
  })


  mod_int_fields     = int_fields ++ ~W(upvoted_by_id downvoted_by_id true_uploader_id hidden_by_id deleted_by_user_id)
  mod_literal_fields = literal_fields ++ ~W(fingerprint upvoted_by downvoted_by true_uploader hidden_by deleted_by_user)
  mod_ip_fields      = ~W(ip)
  mod_bool_fields    = ~W(deleted)
  mod_aliases        =  Map.merge(aliases, %{
    "upvoted_by" => "upvoters",
    "downvoted_by" => "downvoters",
    "upvoted_by_id" => "upvoter_ids",
    "downvoted_by_id" => "downvoter_ids",
    "hidden_by" => "hidden_by_users",
    "hidden_by_id" => "hidden_by_user_ids",
    "deleted" => "hidden_from_users"
  })


  @anonymous_parser Parser.parser(
    int_fields: int_fields,
    float_fields: float_fields,
    date_fields: date_fields,
    literal_fields: literal_fields,
    ngram_fields: ngram_fields,
    custom_fields: custom_fields,
    transforms: transforms,
    aliases: aliases,
    default_field: default_field
  )

  @user_parser Parser.parser(
    int_fields: int_fields,
    float_fields: float_fields,
    date_fields: date_fields,
    literal_fields: literal_fields,
    ngram_fields: ngram_fields,
    custom_fields: user_custom,
    transforms: user_transforms,
    aliases: aliases,
    default_field: default_field
  )

  @moderator_parser Parser.parser(
    int_fields: mod_int_fields,
    float_fields: float_fields,
    date_fields: date_fields,
    literal_fields: mod_literal_fields,
    ip_fields: mod_ip_fields,
    ngram_fields: ngram_fields,
    bool_fields: mod_bool_fields,
    custom_fields: user_custom,
    transforms: user_transforms,
    aliases: mod_aliases,
    default_field: default_field
  )

  def parse_anonymous(context, query_string) do
    Parser.parse(@anonymous_parser, query_string, context)
  end

  def parse_user(context, query_string) do
    Parser.parse(@user_parser, query_string, context)
  end

  def parse_moderator(context, query_string) do
    Parser.parse(@moderator_parser, query_string, context)
  end

  def compile(user, query_string, watch \\ false) do
    query_string = query_string || ""

    case user do
      nil ->
        parse_anonymous(%{user: nil, watch: watch}, query_string)

      %{role: role} when role in ~W(user assistant) ->
        parse_user(%{user: user, watch: watch}, query_string)

      %{role: role} when role in ~W(moderator admin) ->
        parse_moderator(%{user: user, watch: watch}, query_string)

      _ ->
        raise ArgumentError, "Unknown user role."
    end
  end
end
