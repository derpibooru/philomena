defmodule Philomena.DuplicateReports.DuplicateReport do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image
  alias Philomena.Users.User

  schema "duplicate_reports" do
    belongs_to :image, Image
    belongs_to :duplicate_of_image, Image
    belongs_to :user, User
    belongs_to :modifier, User

    field :reason, :string
    field :state, :string, default: "open"

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(duplicate_report, attrs) do
    duplicate_report
    |> cast(attrs, [])
    |> validate_required([])
  end

  @doc false
  def creation_changeset(duplicate_report, attrs, attribution) do
    duplicate_report
    |> cast(attrs, [:reason])
    |> put_assoc(:user, attribution[:user])
    |> validate_length(:reason, max: 250, count: :bytes)
  end
end
