defmodule Philomena.Comments.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  use Philomena.Elasticsearch,
    definition: Philomena.Comments.Elasticsearch,
    index_name: "comments",
    doc_type: "comment"

  alias Philomena.Images.Image
  alias Philomena.Users.User

  schema "comments" do
    belongs_to :user, User
    belongs_to :image, Image
    belongs_to :deleted_by, User

    field :body, :string
    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :user_agent, :string, default: ""
    field :referrer, :string, default: ""
    field :anonymous, :boolean, default: false
    field :hidden_from_users, :boolean, default: false
    field :edit_reason, :string
    field :deletion_reason, :string, default: ""
    field :destroyed_content, :boolean, default: false
    field :name_at_post_time, :string

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [])
    |> validate_required([])
  end
end
