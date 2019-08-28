defmodule Philomena.DuplicateReports.DuplicateReport do
  use Ecto.Schema
  import Ecto.Changeset

  schema "duplicate_reports" do
    belongs_to :image, Philomena.Images.Image
    belongs_to :duplicate_of_image, Philomena.Images.Image
    belongs_to :user, Philomena.Users.User
    belongs_to :modifier, Philomena.Users.User

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
end
