defmodule Philomena.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    belongs_to :user, Philomena.Users.User
    belongs_to :topic, Philomena.Topics.Topic
    belongs_to :deleted_by, Philomena.Users.User

    field :body, :string
    field :edit_reason, :string
    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :user_agent, :string, default: ""
    field :referrer, :string, default: ""
    field :topic_position, :integer
    field :hidden_from_users, :boolean, default: false
    field :anonymous, :boolean, default: false
    field :edited_at, :naive_datetime
    field :deletion_reason, :string, default: ""
    field :destroyed_content, :boolean, default: false
    field :name_at_post_time, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [])
    |> validate_required([])
  end
end
