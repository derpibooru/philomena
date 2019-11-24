defmodule Philomena.Images.Image do
  use Ecto.Schema

  use Philomena.Elasticsearch,
    definition: Philomena.Images.Elasticsearch,
    index_name: "images",
    doc_type: "image"

  import Ecto.Changeset

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

    field :image, :string
    field :image_name, :string
    field :image_width, :integer
    field :image_height, :integer
    field :image_size, :integer
    field :image_format, :string
    field :image_mime_type, :string
    field :image_aspect_ratio, :float
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
    field :is_animated, :boolean
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

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(image, attrs) do
    image
    |> cast(attrs, [])
    |> validate_required([])
  end

  def interaction_data(image) do
    %{
      score: image.score,
      faves: image.faves_count,
      upvotes: image.upvotes_count,
      downvotes: image.downvotes_count
    }
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
  end
end
