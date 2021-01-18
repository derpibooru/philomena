defmodule Philomena.StaticPages.StaticPage do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Phoenix.Param, key: :slug}

  schema "static_pages" do
    field :title, :string
    field :slug, :string
    field :body, :string

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(static_page, attrs) do
    static_page
    |> cast(attrs, [:title, :slug, :body])
    |> validate_required([:title, :slug, :body])
  end
end
