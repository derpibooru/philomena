defmodule Philomena.DataExports.Aggregator do
  @moduledoc """
  Data generation module for data export logic.
  """

  import Ecto.Query
  alias PhilomenaQuery.Batch

  # Direct PII
  alias Philomena.Donations.Donation
  alias Philomena.UserFingerprints.UserFingerprint
  alias Philomena.UserIps.UserIp
  alias Philomena.UserNameChanges.UserNameChange
  alias Philomena.Users.User
  alias Philomena.Users.Settings

  # UGC for export
  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.Badges.Award
  alias Philomena.Comments.Comment
  alias Philomena.Commissions.Commission
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Filters.Filter
  alias Philomena.ImageFaves.ImageFave
  alias Philomena.ImageHides.ImageHide
  alias Philomena.ImageVotes.ImageVote
  alias Philomena.Images.Image
  alias Philomena.PollVotes.PollVote
  alias Philomena.Posts.Post
  alias Philomena.Reports.Report
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.TagChanges.TagChange
  alias Philomena.Topics.Topic
  alias Philomena.Bans

  # Direct UGC from form submission
  @user_columns [
    :created_at,
    :name,
    :email,
    :description,
    :current_filter_id,
    :personal_title
  ]

  # Self-view preferences, selected by user_id
  @user_settings_columns [
    :spoiler_type,
    :theme,
    :images_per_page,
    :comments_per_page,
    :show_sidebar_and_watched_images,
    :fancy_tag_field_on_upload,
    :fancy_tag_field_on_edit,
    :anonymous_by_default,
    :scale_large_images,
    :comments_newest_first,
    :comments_always_jump_to_last,
    :watch_on_reply,
    :watch_on_new_topic,
    :watch_on_upload,
    :messages_newest_first,
    :no_spoilered_in_watched,
    :watched_images_query_str,
    :watched_images_exclude_str,
    :use_centered_layout,
    :hide_vote_counts,
    :delay_home_images,
    :staff_delay_home_images,
    :borderless_tags,
    :rounded_tags
  ]

  # All these also have created_at and are selected by user_id
  @indirect_columns [
    {Donation, [:email, :amount, :fee, :note]},
    {UserFingerprint, [:fingerprint, :uses, :updated_at]},
    {UserIp, [:ip, :uses, :updated_at]},
    {UserNameChange, [:name]},
    {ArtistLink, [:aasm_state, :uri, :public, :tag_id]},
    {Award, [:label, :badge_name, :badge_id]},
    {Comment,
     [
       :ip,
       :fingerprint,
       :user_agent,
       :referrer,
       :anonymous,
       :image_id,
       :edited_at,
       :edit_reason,
       :body
     ]},
    {Commission,
     [:open, :sheet_image_id, :categories, :information, :contact, :will_create, :will_not_create]},
    {DnpEntry, [:tag_id, :aasm_state, :dnp_type, :hide_reason, :feedback, :reason, :instructions],
     :requesting_user_id},
    {DuplicateReport, [:reason, :image_id, :duplicate_of_image_id]},
    {Filter,
     [
       :name,
       :description,
       :public,
       :hidden_complex_str,
       :spoilered_complex_str,
       :hidden_tag_ids,
       :spoilered_tag_ids
     ]},
    {ImageFave, [:image_id], :user_id, :image_id},
    {ImageHide, [:image_id], :user_id, :image_id},
    {ImageVote, [:image_id, :up], :user_id, :image_id},
    {Image, [:ip, :fingerprint, :user_agent, :referrer, :anonymous, :description]},
    {PollVote, [:rank, :poll_option_id]},
    {Post,
     [:ip, :fingerprint, :user_agent, :referrer, :anonymous, :edited_at, :edit_reason, :body]},
    {Report,
     [
       :ip,
       :fingerprint,
       :user_agent,
       :referrer,
       :reason,
       :image_id,
       :comment_id,
       :post_id,
       :reported_user_id,
       :commission_id,
       :conversation_id,
       :gallery_id
     ]},
    {SourceChange, [:ip, :fingerprint, :user_agent, :referrer, :image_id, :added, :value]},
    {TagChange, [:ip, :fingerprint, :image_id]},
    {Topic, [:title, :anonymous, :forum_id]},
    {Bans.User, [:reason, :generated_ban_id]}
  ]

  @doc """
  Get all of the export data for the given user.
  """
  def get_for_user(user_id) do
    [select_user(user_id), select_user_settings(user_id)] ++ select_indirect(user_id)
  end

  defp select_user(user_id) do
    select_schema_by_key(user_id, User, @user_columns, :id)
  end

  defp select_user_settings(user_id) do
    select_schema_by_key(user_id, Settings, @user_settings_columns, :user_id, :user_id)
  end

  defp select_indirect(user_id) do
    Enum.map(@indirect_columns, fn
      {schema_name, columns} ->
        select_schema_by_key(user_id, schema_name, columns)

      {schema_name, columns, key_column} ->
        select_schema_by_key(user_id, schema_name, columns, key_column)

      {schema_name, columns, key_column, id_field} ->
        select_schema_by_key(user_id, schema_name, columns, key_column, id_field)
    end)
  end

  defp select_schema_by_key(
         user_id,
         schema_name,
         columns,
         key_column \\ :user_id,
         id_field \\ :id
       ) do
    table_name = schema_name.__schema__(:source)
    columns = [:created_at] ++ columns

    {"#{table_name}.jsonl",
     schema_name
     |> where([s], field(s, ^key_column) == ^user_id)
     |> select([s], map(s, ^columns))
     |> Batch.records(id_field: id_field)
     |> results_as_json_lines()}
  end

  defp results_as_json_lines(list_of_maps) do
    Stream.map(list_of_maps, fn map ->
      map
      |> Map.new(fn {k, v} -> {k, to_string(v)} end)
      |> JSON.encode!()
      |> Kernel.<>("\n")
    end)
  end
end
