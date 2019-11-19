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
  def creation_changeset(post, attrs, attribution) do
    post
    |> cast(attrs, [:body, :anonymous])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 300_000, count: :bytes)
    |> change(attribution)
    |> put_name_at_post_time()
  end

  @doc false
  def topic_creation_changeset(post, attrs, attribution, anonymous?) do
    post
    |> change(anonymous: anonymous?)
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 300_000, count: :bytes)
    |> change(attribution)
    |> change(topic_position: 0)
    |> put_name_at_post_time()
  end

  defp put_name_at_post_time(%{changes: %{user: %{data: %{name: name}}}} = changeset),
    do: change(changeset, name_at_post_time: name)
  defp put_name_at_post_time(changeset),
    do: changeset
end
