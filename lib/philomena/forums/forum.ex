defmodule Philomena.Forums.Forum do
  use Ecto.Schema
  import Ecto.Changeset

  schema "forums" do
    belongs_to :last_post, Philomena.Forums.Post
    belongs_to :last_topic, Philomena.Forums.Topic

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
