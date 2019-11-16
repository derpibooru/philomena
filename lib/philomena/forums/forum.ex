defmodule Philomena.Forums.Forum do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Posts.Post
  alias Philomena.Topics.Topic

  @derive {Phoenix.Param, key: :short_name}
  schema "forums" do
    belongs_to :last_post, Post
    belongs_to :last_topic, Topic

    field :name, :string
    field :short_name, :string
    field :description, :string
    field :access_level, :string, default: "normal"
    field :topic_count, :integer, default: 0
    field :post_count, :integer, default: 0

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(forum, attrs) do
    forum
    |> cast(attrs, [])
    |> validate_required([])
  end
end