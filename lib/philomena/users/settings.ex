defmodule Philomena.Users.Settings do
  use Ecto.Schema
  import Ecto.Changeset
  import PhilomenaQuery.Ecto.QueryValidator

  alias Philomena.Images.Query

  @type t :: %__MODULE__{}

  @primary_key false
  schema "user_settings" do
    belongs_to :user, Philomena.Users.User, primary_key: true

    field :spoiler_type, :string, default: "static"
    field :theme, :string, default: "dark-blue"
    field :images_per_page, :integer, default: 15
    field :comments_per_page, :integer, default: 20
    field :show_sidebar_and_watched_images, :boolean, default: true
    field :fancy_tag_field_on_upload, :boolean, default: true
    field :fancy_tag_field_on_edit, :boolean, default: true
    field :anonymous_by_default, :boolean, default: false
    field :scale_large_images, :string, default: "true"
    field :comments_newest_first, :boolean, default: true
    field :comments_always_jump_to_last, :boolean, default: true
    field :watch_on_reply, :boolean, default: true
    field :watch_on_new_topic, :boolean, default: true
    field :watch_on_upload, :boolean, default: true
    field :messages_newest_first, :boolean, default: false
    field :no_spoilered_in_watched, :boolean, default: false
    field :watched_images_query_str, :string, default: ""
    field :watched_images_exclude_str, :string, default: ""
    field :use_centered_layout, :boolean, default: true
    field :hide_vote_counts, :boolean, default: false
    field :delay_home_images, :boolean, default: true
    field :staff_delay_home_images, :boolean, default: false
    field :borderless_tags, :boolean, default: false
    field :rounded_tags, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  def changeset(settings, attrs, user) do
    settings
    |> cast(attrs, [
      :images_per_page,
      :fancy_tag_field_on_upload,
      :fancy_tag_field_on_edit,
      :anonymous_by_default,
      :scale_large_images,
      :comments_per_page,
      :theme,
      :watched_images_query_str,
      :no_spoilered_in_watched,
      :watched_images_exclude_str,
      :use_centered_layout,
      :hide_vote_counts,
      :comments_newest_first,
      :watch_on_reply,
      :watch_on_upload,
      :watch_on_new_topic,
      :comments_always_jump_to_last,
      :messages_newest_first,
      :show_sidebar_and_watched_images,
      :delay_home_images,
      :staff_delay_home_images,
      :borderless_tags,
      :rounded_tags
    ])
    |> validate_required([
      :images_per_page,
      :fancy_tag_field_on_upload,
      :fancy_tag_field_on_edit,
      :anonymous_by_default,
      :scale_large_images,
      :comments_per_page,
      :theme,
      :no_spoilered_in_watched,
      :use_centered_layout,
      :hide_vote_counts,
      :watch_on_reply,
      :watch_on_upload,
      :watch_on_new_topic,
      :comments_always_jump_to_last,
      :messages_newest_first,
      :show_sidebar_and_watched_images,
      :borderless_tags,
      :rounded_tags
    ])
    |> validate_inclusion(:theme, themes())
    |> validate_inclusion(:images_per_page, 1..50)
    |> validate_inclusion(:comments_per_page, 1..100)
    |> validate_inclusion(:scale_large_images, ["false", "partscaled", "true"])
    |> validate_length(:watched_images_query_str, max: 10_000, count: :bytes)
    |> validate_length(:watched_images_exclude_str, max: 10_000, count: :bytes)
    |> validate_query(:watched_images_query_str,
      with: &Query.compile(&1, user: user, watch: true)
    )
    |> validate_query(:watched_images_exclude_str,
      with: &Query.compile(&1, user: user, watch: true)
    )
  end

  def spoiler_type_changeset(settings, attrs) do
    settings
    |> cast(attrs, [:spoiler_type])
    |> validate_required([:spoiler_type])
    |> validate_inclusion(:spoiler_type, ~W(static click hover off))
  end

  def theme_colors do
    ~W(red orange yellow green blue purple teal pink gray)
  end

  def theme_names do
    ~W(dark light)
  end

  def themes do
    for name <- theme_names(), color <- theme_colors() do
      "#{name}-#{color}"
    end
  end
end
