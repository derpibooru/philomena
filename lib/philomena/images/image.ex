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
  alias Philomena.Users.User
  alias Philomena.Images.Tagging
  alias Philomena.Galleries

  schema "images" do
    belongs_to :user, User
    belongs_to :deleter, User, source: :deleted_by_id
    has_many :upvotes, ImageVote, where: [up: true]
    has_many :downvotes, ImageVote, where: [up: false]
    has_many :faves, ImageFave
    has_many :hides, ImageHide
    has_many :taggings, Tagging
    has_many :gallery_interactions, Galleries.Interaction
    has_many :tags, through: [:taggings, :tag]
    has_many :upvoters, through: [:upvotes, :user]
    has_many :downvoters, through: [:downvotes, :user]
    has_many :favers, through: [:faves, :user]
    has_many :hiders, through: [:hides, :user]

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

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(image, attrs) do
    image
    |> cast(attrs, [])
    |> validate_required([])
  end
end
