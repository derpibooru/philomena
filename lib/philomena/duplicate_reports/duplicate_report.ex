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

    timestamps(inserted_at: :created_at, type: :utc_datetime)
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
    |> validate_source_is_not_target()
  end

  def accept_changeset(duplicate_report, user) do
    change(duplicate_report)
    |> put_change(:modifier_id, user.id)
    |> put_change(:state, "accepted")
  end

  def claim_changeset(duplicate_report, user) do
    change(duplicate_report)
    |> put_change(:modifier_id, user.id)
    |> put_change(:state, "claimed")
  end

  def unclaim_changeset(duplicate_report) do
    change(duplicate_report)
    |> put_change(:modifier_id, nil)
    |> put_change(:state, "open")
  end

  def reject_changeset(duplicate_report, user) do
    change(duplicate_report)
    |> put_change(:modifier_id, user.id)
    |> put_change(:state, "rejected")
  end

  defp validate_source_is_not_target(changeset) do
    source_id = get_field(changeset, :image_id)
    target_id = get_field(changeset, :duplicate_of_image_id)

    case source_id == target_id do
      true -> add_error(changeset, :image_id, "must be different from the target")
      false -> changeset
    end
  end
end
