defmodule Philomena.Posts.PostVersion do
  use Ecto.Schema

  alias Philomena.Posts.Post
  alias Philomena.Users.User

  @type t :: %__MODULE__{}

  schema "post_versions" do
    belongs_to :post, Post
    belongs_to :user, User

    field :body, :string, default: ""
    field :edit_reason, :string

    field :parent, :any, virtual: true
    field :previous_body, :string, virtual: true
    field :difference, :any, virtual: true

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end
end
