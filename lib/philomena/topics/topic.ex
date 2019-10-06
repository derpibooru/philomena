defmodule Philomena.Topics.Topic do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Phoenix.Param, key: :slug}
  schema "topics" do
    belongs_to :user, Philomena.Users.User
    belongs_to :deleted_by, Philomena.Users.User
    belongs_to :locked_by, Philomena.Users.User
    belongs_to :last_post, Philomena.Posts.Post
    belongs_to :forum, Philomena.Forums.Forum
    has_one :poll, Philomena.Polls.Poll

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
