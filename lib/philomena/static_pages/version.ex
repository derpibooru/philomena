defmodule Philomena.StaticPages.Version do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.StaticPages.StaticPage
  alias Philomena.Users.User

  schema "static_page_versions" do
    belongs_to :static_page, StaticPage
    belongs_to :user, User

    field :title, :string
    field :slug, :string
    field :body, :string

    field :difference, :any, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(version, attrs) do
    version
    |> cast(attrs, [:title, :slug, :body])
    |> validate_required([:title, :slug, :body])
  end
end
