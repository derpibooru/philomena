defmodule Philomena.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  use Philomena.Elasticsearch,
    definition: Philomena.Posts.Elasticsearch,
    index_name: "posts",
    doc_type: "post"

  alias Philomena.Users.User
  alias Philomena.Topics.Topic

  schema "posts" do
    belongs_to :user, User
    belongs_to :topic, Topic
    belongs_to :deleted_by, User

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

  @doc false
  def creation_changeset(post, user, attrs) do
    post
    |> cast(attrs, [:body, :anonymous])
    |> set_name_at_post_time(user)
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 300_000, count: :bytes)
  end

  def set_name_at_post_time(changeset, nil), do: changeset
  def set_name_at_post_time(changeset, %{name: name}) do
    change(changeset, name_at_post_time: name)
  end
end
