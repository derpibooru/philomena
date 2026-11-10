defmodule Philomena.Users.Query do
  alias PhilomenaQuery.Parse.Parser

  defp fields do
    [
      int_fields:
        ~W(id posts_count topics_count images_count image_votes_count comments_count metadata_updates_count image_faves_count),
      numeric_fields: ~W(deleted_by_user_id current_filter_id forced_filter_id),
      date_fields: ~W(created_at confirmed_at locked_at deleted_at banned_until last_renamed_at),
      literal_fields: ~W(name slug role email deleted_by_user names),
      bool_fields: ~W(otp_required_for_login confirmed locked deleted custom_avatar verified),
      ngram_fields: ~W(description scratchpad personal_title),
      default_field: {"name_or_email", :term}
    ]
  end

  def compile(query_string) do
    fields()
    |> Parser.new()
    |> Parser.parse(query_string)
  end
end
