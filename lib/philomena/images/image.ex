defmodule Philomena.Images.Image do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Philomena.ImageIntensities.ImageIntensity
  alias Philomena.ImageVotes.ImageVote
  alias Philomena.ImageFaves.ImageFave
  alias Philomena.ImageHides.ImageHide
  alias Philomena.Images.Source
  alias Philomena.Images.Subscription
  alias Philomena.Users.User
  alias Philomena.Tags.Tag
  alias Philomena.Galleries
  alias Philomena.Comments.Comment
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.TagChanges.TagChange

  alias Philomena.Images.Image
  alias Philomena.Images.TagDiffer
  alias Philomena.Images.SourceDiffer
  alias Philomena.Images.TagValidator
  alias Philomena.Images.DnpValidator
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
    has_many :source_changes, SourceChange, on_replace: :delete
    has_many :tag_changes, TagChange
    has_many :upvoters, through: [:upvotes, :user]
    has_many :downvoters, through: [:downvotes, :user]
    has_many :favers, through: [:faves, :user]
    has_many :hiders, through: [:hides, :user]
    many_to_many :tags, Tag, join_through: "image_taggings", on_replace: :delete
    many_to_many :locked_tags, Tag, join_through: "image_tag_locks", on_replace: :delete
    has_one :intensity, ImageIntensity
    has_many :galleries, through: [:gallery_interactions, :image]
    has_many :sources, Source, on_replace: :delete

    field :image, :string
    field :image_name, :string
    field :image_width, :integer
    field :image_height, :integer
    field :image_size, :integer
    field :image_format, :string
    field :image_mime_type, :string
    field :image_aspect_ratio, :float
    field :image_duration, :float
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
    field :first_seen_at, :utc_datetime
    field :destroyed_content, :boolean
    field :hidden_image_key, :string
    field :scratchpad, :string
    field :hides_count, :integer, default: 0
    field :approved, :boolean

    # todo: can probably remove these now
    field :tag_list_cache, :string
    field :tag_list_plus_alias_cache, :string
    field :file_name_cache, :string

    field :removed_tags, {:array, :any}, default: [], virtual: true
    field :added_tags, {:array, :any}, default: [], virtual: true
    field :removed_sources, {:array, :any}, default: [], virtual: true
    field :added_sources, {:array, :any}, default: [], virtual: true

    field :uploaded_image, :string, virtual: true
    field :removed_image, :string, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
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
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    image
    |> cast(attrs, [:anonymous, :source_url, :description])
    |> change(first_seen_at: now)
    |> change(attribution)
    |> validate_length(:description, max: 50_000, count: :bytes)
    |> validate_format(:source_url, ~r/\Ahttps?:\/\//)
  end

  def image_changeset(image, attrs) do
    image
    |> cast(attrs, [
      :image,
      :image_name,
      :image_width,
      :image_height,
      :image_size,
      :image_format,
      :image_mime_type,
      :image_aspect_ratio,
      :image_duration,
      :image_orig_sha512_hash,
      :image_sha512_hash,
      :uploaded_image,
      :removed_image,
      :image_is_animated
    ])
    |> validate_required([
      :image,
      :image_width,
      :image_height,
      :image_size,
      :image_format,
      :image_mime_type,
      :image_aspect_ratio,
      :image_duration,
      :image_orig_sha512_hash,
      :image_sha512_hash,
      :uploaded_image,
      :image_is_animated
    ])
    |> validate_number(:image_size, greater_than: 0, less_than_or_equal_to: 125_000_000)
    |> validate_length(:image_name, max: 255, count: :bytes)
    |> validate_inclusion(
      :image_mime_type,
      ~W(image/gif image/jpeg image/png image/svg+xml video/webm),
      message: "(#{attrs["image_mime_type"]}) is invalid"
    )
    |> check_dimensions()
    |> prepare_changes(fn changeset ->
      sha512 = fetch_field!(changeset, :image_orig_sha512_hash)
      other_image = Repo.get_by(Image, image_orig_sha512_hash: sha512)

      if not is_nil(other_image) do
        add_error(changeset, :image, "has already been uploaded: it's image #{other_image.id}")
      else
        changeset
      end
    end)
  end

  defp check_dimensions(changeset) do
    width = fetch_field!(changeset, :image_width)
    height = fetch_field!(changeset, :image_height)

    cond do
      width <= 0 or height <= 0 ->
        add_error(
          changeset,
          :image,
          "contents corrupt, not recognized, or dimensions are too large to process"
        )

      width > 32767 or height > 32767 ->
        add_error(changeset, :image, "side dimensions are larger than 32767 px")

      true ->
        changeset
    end
  end

  def remove_image_changeset(image) do
    image
    |> change(removed_image: image.image)
    |> change(image: nil)
  end

  def source_changeset(image, attrs, old_sources, new_sources) do
    image
    |> cast(attrs, [])
    |> SourceDiffer.diff_input(old_sources, new_sources)
  end

  def sources_changeset(image, new_sources) do
    change(image)
    |> put_assoc(:sources, new_sources)
  end

  def tag_changeset(image, attrs, old_tags, new_tags, excluded_tags \\ []) do
    image
    |> cast(attrs, [])
    |> TagDiffer.diff_input(old_tags, new_tags, excluded_tags)
    |> TagValidator.validate_tags()
    |> cache_changeset()
  end

  def locked_tags_changeset(image, attrs, locked_tags) do
    image
    |> cast(attrs, [])
    |> put_assoc(:locked_tags, locked_tags)
  end

  def dnp_changeset(image, user) do
    image
    |> change()
    |> DnpValidator.validate_dnp(user)
  end

  def thumbnail_changeset(image, attrs) do
    image
    |> cast(attrs, [:image_sha512_hash, :image_size, :image_width, :image_height])
    |> change(thumbnails_generated: true, duplication_checked: true)
  end

  def process_changeset(image, attrs) do
    image
    |> cast(attrs, [:image_sha512_hash, :image_size, :image_width, :image_height])
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
    |> validate_not_hidden()
    |> put_change(:deleter_id, user.id)
    |> put_change(:hidden_image_key, create_key())
    |> put_change(:hidden_from_users, true)
    |> validate_required([:deletion_reason, :deleter_id])
  end

  def hide_reason_changeset(image, attrs) do
    image
    |> cast(attrs, [:deletion_reason])
    |> validate_required([:deletion_reason])
  end

  def merge_changeset(image, duplicate_of_image) do
    change(image)
    |> validate_not_hidden()
    |> put_change(:duplicate_id, duplicate_of_image.id)
    |> put_change(:hidden_image_key, create_key())
    |> put_change(:hidden_from_users, true)
  end

  def unhide_changeset(image) do
    change(image)
    |> validate_hidden()
    |> put_change(:deleter_id, nil)
    |> put_change(:hidden_image_key, nil)
    |> put_change(:hidden_from_users, false)
    |> put_change(:deletion_reason, nil)
    |> put_change(:duplicate_id, nil)
  end

  def lock_comments_changeset(image, locked) do
    change(image, commenting_allowed: not locked)
  end

  def lock_description_changeset(image, locked) do
    change(image, description_editing_allowed: not locked)
  end

  def lock_tags_changeset(image, locked) do
    change(image, tag_editing_allowed: not locked)
  end

  def remove_hash_changeset(image) do
    change(image, image_orig_sha512_hash: nil)
  end

  def scratchpad_changeset(image, attrs) do
    cast(image, attrs, [:scratchpad])
  end

  def remove_source_history_changeset(image) do
    change(image)
    |> put_change(:source_url, nil)
    |> put_assoc(:source_changes, [])
  end

  def uploader_changeset(image, attrs) do
    user_id =
      if attrs["username"] not in [nil, ""] do
        Repo.get_by!(User, name: attrs["username"]).id
      else
        nil
      end

    change(image)
    |> put_change(:user_id, user_id)
    |> put_change(:ip, %Postgrex.INET{address: {127, 0, 0, 1}, netmask: 32})
    |> put_change(:fingerprint, "ffff")
  end

  def anonymous_changeset(image, attrs) do
    cast(image, attrs, [:anonymous])
  end

  def approve_changeset(image) do
    change(image)
    |> put_change(:approved, true)
    |> put_change(:first_seen_at, DateTime.truncate(DateTime.utc_now(), :second))
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

    tag_ids = tags |> Enum.map(& &1.id)

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
      |> String.to_charlist()
      |> Enum.filter(&(&1 in ?a..?z or &1 in ~c"0123456789_-"))
      |> List.to_string()
      |> String.slice(0..150)

    file_name_cache = "#{image_id}__#{file_name_slug_fragment}"

    {tag_list_cache, tag_list_plus_alias_cache, file_name_cache}
  end

  defp create_key do
    Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)
  end

  defp validate_hidden(changeset) do
    case get_field(changeset, :hidden_from_users) do
      true -> changeset
      false -> add_error(changeset, :hidden_from_users, "must be true")
    end
  end

  defp validate_not_hidden(changeset) do
    case get_field(changeset, :hidden_from_users) do
      true -> add_error(changeset, :hidden_from_users, "must be false")
      false -> changeset
    end
  end
end
