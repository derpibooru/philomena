defmodule Philomena.Topics.Topic do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Forums.Forum
  alias Philomena.Users.User
  alias Philomena.Polls.Poll
  alias Philomena.Posts.Post
  alias Philomena.Topics.Subscription
  alias Philomena.Slug

  @derive {Phoenix.Param, key: :slug}
  schema "topics" do
    belongs_to :user, User
    belongs_to :deleted_by, User
    belongs_to :locked_by, User
    belongs_to :last_post, Post
    belongs_to :forum, Forum
    has_one :poll, Poll
    has_many :posts, Post
    has_many :subscriptions, Subscription

    field :title, :string
    field :post_count, :integer, default: 1
    field :view_count, :integer, default: 0
    field :sticky, :boolean, default: false
    field :last_replied_to_at, :naive_datetime
    field :locked_at, :naive_datetime
    field :deletion_reason, :string
    field :lock_reason, :string
    field :slug, :string
    field :anonymous, :boolean, default: false
    field :hidden_from_users, :boolean, default: false

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(topic, attrs) do
    topic
    |> cast(attrs, [])
    |> validate_required([])
  end

  @doc false
  def creation_changeset(topic, attrs, forum, attribution) do
    changes =
      topic
      |> cast(attrs, [:title, :anonymous])
      |> validate_required([:title, :anonymous])

    anonymous? =
      changes
      |> get_field(:anonymous)

    changes
    |> validate_length(:title, min: 4, max: 96, count: :bytes)
    |> put_slug()
    |> change(forum: forum, user: attribution[:user])
    |> validate_required(:forum)
    |> cast_assoc(:poll, with: &Poll.creation_changeset/2)
    |> cast_assoc(:posts, with: {Post, :topic_creation_changeset, [attribution, anonymous?]})
    |> validate_length(:posts, is: 1)
    |> unique_constraint(:slug, name: :index_topics_on_forum_id_and_slug)
  end

  def put_slug(changeset) do
    slug =
      changeset
      |> get_field(:title)
      |> Slug.destructive_slug()

    changeset
    |> put_change(:slug, slug)
    |> validate_required(:slug, message: "must be printable")
  end
end
