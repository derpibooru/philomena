defmodule Philomena.Images.Image do
  use Ecto.Schema

  use Philomena.Elasticsearch,
    definition: Philomena.Images.Elasticsearch,
    index_name: "images",
    doc_type: "image"

  import Ecto.Changeset
  import Ecto.Query

  alias Philomena.ImageIntensities.ImageIntensity
  alias Philomena.ImageVotes.ImageVote
  alias Philomena.ImageFaves.ImageFave
  alias Philomena.ImageHides.ImageHide
  alias Philomena.Images.Subscription
  alias Philomena.Users.User
  alias Philomena.Tags.Tag
  alias Philomena.Galleries
  alias Philomena.Comments.Comment
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.TagChanges.TagChange

  alias Philomena.Images.TagDiffer
  alias Philomena.Images.TagValidator
  alias Philomena.Repo

  schema "images" do
    belongs_to :user, User
    belongs_to :deleter, User, source: :deleted_by_id
    has_many :comments, Comment
    has_many :upvotes, ImageVote, where: [up: true]
    has_many :downvotes, ImageVote, where: [up: false]
    has_many :faves, ImageFave
    has_many :hides, ImageHide
    has_many :gallery_interactions, Galleries.Interaction
    has_many :subscriptions, Subscription
    has_many :source_changes, SourceChange
    has_many :tag_changes, TagChange
    has_many :upvoters, through: [:upvotes, :user]
    has_many :downvoters, through: [:downvotes, :user]
    has_many :favers, through: [:faves, :user]
    has_many :hiders, through: [:hides, :user]
    many_to_many :tags, Tag, join_through: "image_taggings", on_replace: :delete
    has_one :intensity, ImageIntensity
    has_many :galleries, through: [:gallery_interactions, :image]

    field :image, :string
    field :image_name, :string
    field :image_width, :integer
    field :image_height, :integer
    field :image_size, :integer
    field :image_format, :string
    field :image_mime_type, :string
    field :image_aspect_ratio, :float
    field :image_is_animated, :boolean, source: :is_animated
    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :user_agent, :string, default: ""
    field :referrer, :string, default: ""
    field :anonymous, :boolean, default: false
    field :score, :integer, default: 0
    field :faves_count, :integer, default: 0
    field :upvotes_count, :integer, default: 0
    field :downvotes_count, :integer, default: 0
    field :votes_count, :integer, default: 0
    field :source_url, :string
    field :description, :string, default: ""
    field :image_sha512_hash, :string
    field :image_orig_sha512_hash, :string
    field :deletion_reason, :string
    field :duplicate_id, :integer
    field :comments_count, :integer, default: 0
    field :processed, :boolean, default: false
    field :thumbnails_generated, :boolean, default: false
    field :duplication_checked, :boolean, default: false
    field :hidden_from_users, :boolean, default: false
    field :tag_editing_allowed, :boolean, default: true
    field :description_editing_allowed, :boolean, default: true
    field :commenting_allowed, :boolean, default: true
    field :first_seen_at, :naive_datetime
    field :destroyed_content, :boolean
    field :hidden_image_key, :string
    field :scratchpad, :string
    field :hides_count, :integer, default: 0

    # todo: can probably remove these now
    field :tag_list_cache, :string
    field :tag_list_plus_alias_cache, :string
    field :file_name_cache, :string

    field :removed_tags, {:array, :any}, default: [], virtual: true
    field :added_tags, {:array, :any}, default: [], virtual: true

    field :uploaded_image, :string, virtual: true
    field :removed_image, :string, virtual: true

    timestamps(inserted_at: :created_at)
  end

  def interaction_data(image) do
    %{
      score: image.score,
      faves: image.faves_count,
      upvotes: image.upvotes_count,
      downvotes: image.downvotes_count
    }
  end

  @doc false
  def changeset(image, attrs) do
    image
    |> cast(attrs, [])
    |> validate_required([])
  end

  def creation_changeset(image, attrs, attribution) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    image
    |> cast(attrs, [:anonymous, :source_url, :description])
    |> change(first_seen_at: now)
    |> change(attribution)
    |> validate_length(:description, max: 50_000, count: :bytes)
  end

  def image_changeset(image, attrs) do
    image
    |> cast(attrs, [
      :image, :image_name, :image_width, :image_height, :image_size,
      :image_format, :image_mime_type, :image_aspect_ratio,
      :image_orig_sha512_hash, :image_sha512_hash, :uploaded_image,
      :removed_image, :image_is_animated
    ])
    |> validate_required([
      :image, :image_width, :image_height, :image_size,
      :image_format, :image_mime_type, :image_aspect_ratio,
      :image_orig_sha512_hash, :image_sha512_hash, :uploaded_image,
      :image_is_animated
    ])
    |> validate_number(:image_size, greater_than: 0, less_than_or_equal_to: 26214400)
    |> validate_number(:image_width, greater_than: 0, less_than_or_equal_to: 32767)
    |> validate_number(:image_height, greater_than: 0, less_than_or_equal_to: 32767)
    |> validate_length(:image_name, max: 255, count: :bytes)
    |> validate_inclusion(:image_mime_type, ~W(image/gif image/jpeg image/png image/svg+xml video/webm))
    |> unsafe_validate_unique([:image_orig_sha512_hash], Repo)
  end

  def source_changeset(image, attrs) do
    image
    |> cast(attrs, [:source_url])
    |> validate_required(:source_url)
    |> validate_format(:source_url, ~r/\Ahttps?:\/\//)
  end

  def tag_changeset(image, attrs, old_tags, new_tags) do
    image
    |> cast(attrs, [])
    |> TagDiffer.diff_input(old_tags, new_tags)
    |> TagValidator.validate_tags()
    |> cache_changeset()
  end

  def thumbnail_changeset(image, attrs) do
    image
    |> cast(attrs, [:image_sha512_hash])
    |> change(thumbnails_generated: true, duplication_checked: true)
  end

  def process_changeset(image, attrs) do
    image
    |> cast(attrs, [:image_sha512_hash])
    |> change(processed: true)
  end

  def description_changeset(image, attrs) do
    image
    |> cast(attrs, [:description])
    |> validate_length(:description, max: 50_000, count: :bytes)
  end

  def hide_changeset(image, attrs, user) do
    image
    |> cast(attrs, [:deletion_reason])
    |> put_change(:deleter_id, user.id)
    |> put_change(:hidden_image_key, create_key())
    |> put_change(:hidden_from_users, true)
    |> validate_required([:deletion_reason, :deleter_id])
  end

  def merge_changeset(image, duplicate_of_image) do
    change(image)
    |> put_change(:duplicate_id, duplicate_of_image.id)
    |> put_change(:hidden_image_key, create_key())
    |> put_change(:hidden_from_users, true)
  end

  def unhide_changeset(image) do
    change(image)
    |> put_change(:deleter_id, nil)
    |> put_change(:hidden_image_key, nil)
    |> put_change(:hidden_from_users, false)
    |> put_change(:deletion_reason, nil)
  end

  def cache_changeset(image) do
    changeset = change(image)
    image = apply_changes(changeset)

    {tag_list_cache, tag_list_plus_alias_cache, file_name_cache} =
      create_caches(image.id, image.tags)

    changeset
    |> put_change(:tag_list_cache, tag_list_cache)
    |> put_change(:tag_list_plus_alias_cache, tag_list_plus_alias_cache)
    |> put_change(:file_name_cache, file_name_cache)
  end

  defp create_caches(image_id, tags) do
    tags = Tag.display_order(tags)

    tag_list_cache =
      tags
      |> Enum.map_join(", ", & &1.name)

    tag_ids =
      tags |> Enum.map(& &1.id)

    aliases =
      Tag
      |> where([t], t.aliased_tag_id in ^tag_ids)
      |> Repo.all()

    tag_list_plus_alias_cache =
      (tags ++ aliases)
      |> Tag.display_order()
      |> Enum.map_join(", ", & &1.name)

    # Truncate filename to 150 characters, making room for the path + filename on Windows
    # https://stackoverflow.com/questions/265769/maximum-filename-length-in-ntfs-windows-xp-and-windows-vista
    file_name_slug_fragment =
      tags
      |> Enum.map_join("_", & &1.slug)
      |> String.replace("%2F", "")
      |> String.replace("/", "")
      |> String.slice(0..150)

    file_name_cache = "#{image_id}__#{file_name_slug_fragment}"

    {tag_list_cache, tag_list_plus_alias_cache, file_name_cache}
  end

  defp create_key do
    Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)
  end
end
