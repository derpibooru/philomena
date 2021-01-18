defmodule Philomena.Forums.Forum do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Posts.Post
  alias Philomena.Topics.Topic
  alias Philomena.Forums.Subscription

  @derive {Phoenix.Param, key: :short_name}
  schema "forums" do
    belongs_to :last_post, Post
    belongs_to :last_topic, Topic
    has_many :subscriptions, Subscription

    field :name, :string
    field :short_name, :string
    field :description, :string
    field :access_level, :string, default: "normal"
    field :topic_count, :integer, default: 0
    field :post_count, :integer, default: 0

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(forum, attrs) do
    forum
    |> cast(attrs, [:name, :short_name, :description, :access_level])
    |> validate_required([:name, :short_name, :description, :access_level])
    |> validate_inclusion(:access_level, ~W(normal assistant staff))
    |> validate_format(:short_name, ~r/\A[a-z]+\z/,
      message: "must consist only of lowercase letters"
    )
    |> unique_constraint(:short_name, name: :index_forums_on_short_name)
  end
end
