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
    field :last_replied_to_at, :utc_datetime
    field :locked_at, :utc_datetime
    field :deletion_reason, :string
    field :lock_reason, :string
    field :slug, :string
    field :anonymous, :boolean, default: false
    field :hidden_from_users, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
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
    |> cast_assoc(:poll, with: &Poll.update_changeset/2)
    |> cast_assoc(:posts, with: {Post, :topic_creation_changeset, [attribution, anonymous?]})
    |> validate_length(:posts, is: 1)
    |> unique_constraint(:slug, name: :index_topics_on_forum_id_and_slug)
  end

  def stick_changeset(topic) do
    change(topic)
    |> put_change(:sticky, true)
  end

  def unstick_changeset(topic) do
    change(topic)
    |> put_change(:sticky, false)
  end

  def lock_changeset(topic, attrs, user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    change(topic)
    |> cast(attrs, [:lock_reason])
    |> put_change(:locked_at, now)
    |> put_change(:locked_by_id, user.id)
    |> validate_required([:lock_reason])
  end

  def unlock_changeset(topic) do
    change(topic)
    |> put_change(:locked_at, nil)
    |> put_change(:locked_by_id, nil)
    |> put_change(:lock_reason, "")
  end

  def move_changeset(topic, new_forum_id) do
    change(topic)
    |> put_change(:forum_id, new_forum_id)
  end

  def hide_changeset(topic, deletion_reason, user) do
    change(topic)
    |> put_change(:hidden_from_users, true)
    |> put_change(:deleted_by_id, user.id)
    |> put_change(:deletion_reason, deletion_reason)
    |> validate_required([:deletion_reason])
  end

  def unhide_changeset(topic) do
    change(topic)
    |> put_change(:hidden_from_users, false)
    |> put_change(:deleted_by_id, nil)
    |> put_change(:deletion_reason, "")
  end

  def title_changeset(topic, attrs) do
    topic
    |> cast(attrs, [:title])
    |> validate_required([:title])
    |> validate_length(:title, min: 4, max: 96, count: :bytes)
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
