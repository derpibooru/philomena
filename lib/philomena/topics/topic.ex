defmodule Philomena.Topics.Topic do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Forums.Forum
  alias Philomena.Users.User
  alias Philomena.Polls.Poll
  alias Philomena.Posts.Post

  @derive {Phoenix.Param, key: :slug}
  schema "topics" do
    belongs_to :user, User
    belongs_to :deleted_by, User
    belongs_to :locked_by, User
    belongs_to :last_post, Post
    belongs_to :forum, Forum
    has_one :poll, Poll

    field :title, :string
    field :post_count, :integer, default: 0
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
end
