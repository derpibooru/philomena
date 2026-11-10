defmodule Philomena.Images.Image do
  use Ecto.Schema

  import Bitwise
  import Ecto.Changeset

  alias Philomena.Attribution.Actor
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
  alias Philomena.Reports.Report

  alias Philomena.Images.Image
  alias Philomena.Images.TagDiffer
  alias Philomena.Images.SourceDiffer
  alias Philomena.Images.TagValidator
  alias Philomena.Images.DnpValidator

  @type t :: %__MODULE__{}

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
    has_many :subscribers, through: [:subscriptions, :user]
    many_to_many :tags, Tag, join_through: "image_taggings", on_replace: :delete
    many_to_many :locked_tags, Tag, join_through: "image_tag_locks", on_replace: :delete
    has_one :intensity, ImageIntensity
    has_many :galleries, through: [:gallery_interactions, :image]
    has_many :sources, Source, on_replace: :delete
    has_many :reports, Report

    field :image, :string
    field :image_name, :string
    field :image_width, :integer
    field :image_height, :integer
    field :image_size, :integer
    field :image_orig_size, :integer
    field :image_format, :string
    field :image_mime_type, :string
    field :image_aspect_ratio, :float
    field :image_duration, :float
    field :image_is_animated, :boolean, source: :is_animated
    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :anonymous, :boolean, default: false
    field :score, :integer, default: 0
    field :faves_count, :integer, default: 0
    field :upvotes_count, :integer, default: 0
    field :downvotes_count, :integer, default: 0
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

    field :removed_tags, {:array, :any}, default: [], virtual: true
    field :added_tags, {:array, :any}, default: [], virtual: true
    field :removed_sources, {:array, :any}, default: [], virtual: true
    field :added_sources, {:array, :any}, default: [], virtual: true
    field :ratings_changed, :boolean, default: false, virtual: true

    field :uploaded_image, :string, virtual: true
    field :removed_image, :string, virtual: true

    field :tag_change_count, :integer, virtual: true
    field :tag_change_tag_count, :integer, virtual: true
    field :source_change_count, :integer, virtual: true

    field :username, :string, virtual: true

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

  def creation_changeset(image, attrs, %Actor{} = actor) do
    image
    |> cast(attrs, [:anonymous, :source_url, :description])
    |> change(first_seen_at: DateTime.utc_now(:second))
    |> change(Actor.to_changes(actor))
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
      :image_orig_size,
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
      :image_orig_size,
      :image_format,
      :image_mime_type,
      :image_aspect_ratio,
      :image_duration,
      :image_orig_sha512_hash,
      :image_sha512_hash,
      :uploaded_image,
      :image_is_animated
    ])
    |> validate_number(:image_size, greater_than: 0, less_than_or_equal_to: 131_072_000)
    |> validate_length(:image_name, max: 255, count: :bytes)
    |> validate_inclusion(
      :image_mime_type,
      ~W(image/gif image/jpeg image/png image/svg+xml video/webm),
      message: "(#{attrs["image_mime_type"]}) is invalid"
    )
    |> check_dimensions()
    |> prepare_changes(fn changeset ->
      # This is just to give a nicer validation failure error message within Ecto.
      # The image sha512 field has a real unique constraint.
      sha512 = fetch_field!(changeset, :image_orig_sha512_hash)
      other_image = changeset.repo.get_by(Image, image_orig_sha512_hash: sha512)

      if is_nil(other_image) or other_image.id == changeset.data.id do
        changeset
      else
        add_error(changeset, :image, "has already been uploaded: it's image #{other_image.id}")
      end
    end)
  end

  defp check_dimensions(changeset) do
    width = fetch_field!(changeset, :image_width)
    height = fetch_field!(changeset, :image_height)

    cond do
      is_nil(width) or is_nil(height) or width <= 0 or height <= 0 ->
        add_error(
          changeset,
          :image,
          "contents corrupt, not recognized, or dimensions are too large to process"
        )

      ((width + 63 &&& -64) * 8 + 1024) * (height + 128) >= 2_147_483_647 ->
        add_error(changeset, :image, "dimensions are too large to process")

      true ->
        changeset
    end
  end

  def remove_image_changeset(image) do
    image
    |> change()
    |> validate_hidden()
    |> validate_not_destroyed()
    |> change(destroyed_content: true, removed_image: image.image, image: nil)
  end

  def source_changeset(image, added_sources, removed_sources) do
    image
    |> change()
    |> SourceDiffer.apply(added_sources, removed_sources)
    |> validate_length(:sources, max: 15)
  end

  def meaningful_source_update?(changeset) do
    added = get_field(changeset, :added_sources)
    removed = get_field(changeset, :removed_sources)

    not (Enum.empty?(added) and Enum.empty?(removed))
  end

  def sources_changeset(image, new_sources) do
    change(image)
    |> put_assoc(:sources, new_sources)
    |> validate_length(:sources, max: 15)
  end

  def tag_changeset(image, added_tags, removed_tags, excluded_tags \\ []) do
    image
    |> change()
    |> TagDiffer.apply(added_tags, removed_tags, excluded_tags)
    |> TagValidator.validate_tags()
  end

  def meaningful_tag_update?(changeset) do
    added = get_field(changeset, :added_tags)
    removed = get_field(changeset, :removed_tags)

    not (Enum.empty?(added) and Enum.empty?(removed))
  end

  def locked_tags_changeset(image, attrs, locked_tags) do
    image
    |> cast(attrs, [])
    |> put_assoc(:locked_tags, locked_tags)
  end

  def dnp_changeset(image, user, tags_with_dnp) do
    image
    |> change()
    |> DnpValidator.validate_dnp(user, tags_with_dnp)
  end

  def thumbnail_changeset(image, attrs) do
    image
    |> cast(attrs, [
      :image_sha512_hash,
      :image_size,
      :image_width,
      :image_height,
      :image_aspect_ratio
    ])
    |> change(thumbnails_generated: true, duplication_checked: true)
  end

  def process_changeset(image, attrs) do
    image
    |> cast(attrs, [
      :image_sha512_hash,
      :image_size,
      :image_width,
      :image_height,
      :image_aspect_ratio
    ])
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
    |> put_change(:approved, true)
    |> validate_required([:deletion_reason, :deleter_id])
  end

  def hide_reason_changeset(image, attrs) do
    image
    |> cast(attrs, [:deletion_reason])
    |> validate_required([:deletion_reason])
    |> validate_hidden()
  end

  def merge_source_changeset(image, duplicate_of_image) do
    image
    |> change()
    |> validate_not_hidden()
    |> validate_merge_target(duplicate_of_image)
    |> put_change(:duplicate_id, duplicate_of_image.id)
    |> put_change(:hidden_image_key, create_key())
    |> put_change(:hidden_from_users, true)
  end

  def first_seen_at_changeset(image, candidate_images) do
    candidate_images
    |> Enum.map(& &1.first_seen_at)
    |> Enum.min(DateTime)
    |> then(&change(image, first_seen_at: &1))
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

  def username_changeset(image, attrs) do
    cast(image, attrs, [:username])
  end

  def uploader_changeset(image, username, uploader) do
    image
    |> change()
    |> put_change(:ip, %Postgrex.INET{address: {127, 0, 0, 1}, netmask: 32})
    |> put_change(:fingerprint, "ffff")
    |> put_uploader(username, uploader)
  end

  # A blank username anonymizes the image.
  defp put_uploader(changeset, username, nil) do
    if username do
      add_error(changeset, :username, "does not name a known user")
    else
      put_change(changeset, :user_id, nil)
    end
  end

  defp put_uploader(changeset, _username, uploader) do
    put_change(changeset, :user_id, uploader.id)
  end

  def anonymous_changeset(image, attrs) do
    cast(image, attrs, [:anonymous])
  end

  def approve_changeset(image) do
    change(image)
    |> validate_not_approved()
    |> put_change(:approved, true)
    |> put_change(:first_seen_at, DateTime.utc_now(:second))
  end

  defp create_key do
    Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)
  end

  defp validate_hidden(changeset) do
    if get_field(changeset, :hidden_from_users) do
      changeset
    else
      add_error(changeset, :hidden_from_users, "must be true")
    end
  end

  defp validate_not_hidden(changeset) do
    if get_field(changeset, :hidden_from_users) do
      add_error(changeset, :hidden_from_users, "must be false")
    else
      changeset
    end
  end

  defp validate_merge_target(changeset, %__MODULE__{hidden_from_users: true}) do
    add_error(changeset, :duplicate_id, "must refer to a visible image")
  end

  defp validate_merge_target(changeset, %__MODULE__{}), do: changeset

  defp validate_not_approved(changeset) do
    if get_field(changeset, :approved) do
      add_error(changeset, :approved, "must be false")
    else
      changeset
    end
  end

  defp validate_not_destroyed(changeset) do
    if get_field(changeset, :destroyed_content) do
      add_error(changeset, :destroyed_content, "must be false")
    else
      changeset
    end
  end
end
