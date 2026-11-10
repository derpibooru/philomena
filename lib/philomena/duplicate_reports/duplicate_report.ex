defmodule Philomena.DuplicateReports.DuplicateReport do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image
  alias Philomena.Users.User

  @type t :: %__MODULE__{}

  schema "duplicate_reports" do
    belongs_to :image, Image
    belongs_to :duplicate_of_image, Image
    belongs_to :user, User
    belongs_to :modifier, User

    field :reason, :string, default: ""
    field :state, :string, default: "open"

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  def open_states do
    ~w(open claimed)
  end

  def valid_states do
    ~w(open claimed accepted rejected)
  end

  @doc false
  def creation_changeset(duplicate_report, attrs, user \\ nil) do
    duplicate_report
    |> cast(attrs, [:reason])
    |> put_assoc(:user, user)
    |> validate_length(:reason, max: 250, count: :bytes)
    |> validate_source_is_not_target()
  end

  @doc false
  def accept_changeset(duplicate_report, user) do
    change(duplicate_report)
    |> validate_actionable()
    |> put_change(:modifier_id, user.id)
    |> put_change(:state, "accepted")
  end

  @doc false
  def reverse_accept_changeset(duplicate_report, user, reason) do
    suffix = "\n(Reverse accepted)"
    reason = String.byte_slice(reason, 0, 250 - byte_size(suffix))

    duplicate_report
    |> creation_changeset(%{reason: reason <> suffix}, user)
    |> accept_changeset(user)
  end

  @doc false
  def claim_changeset(duplicate_report, user) do
    change(duplicate_report)
    |> validate_state("open", "must be open")
    |> validate_unclaimed()
    |> put_change(:modifier_id, user.id)
    |> put_change(:state, "claimed")
  end

  @doc false
  def unclaim_changeset(duplicate_report) do
    change(duplicate_report)
    |> validate_state("claimed", "must be claimed")
    |> validate_claimed()
    |> put_change(:modifier_id, nil)
    |> put_change(:state, "open")
  end

  @doc false
  def reject_changeset(duplicate_report, user) do
    change(duplicate_report)
    |> validate_actionable()
    |> put_change(:modifier_id, user.id)
    |> put_change(:state, "rejected")
  end

  @doc false
  def add_image_acceptance_error(duplicate_report) do
    duplicate_report
    |> change()
    |> add_error(:image_id, "rejected the merge")
  end

  defp validate_actionable(changeset) do
    if get_field(changeset, :state) in ["open", "claimed"] do
      changeset
    else
      add_error(changeset, :state, "must be open or claimed")
    end
  end

  defp validate_state(changeset, expected, message) do
    if get_field(changeset, :state) == expected do
      changeset
    else
      add_error(changeset, :state, message)
    end
  end

  defp validate_unclaimed(changeset) do
    if is_nil(get_field(changeset, :modifier_id)) do
      changeset
    else
      add_error(changeset, :modifier_id, "has already been claimed")
    end
  end

  defp validate_claimed(changeset) do
    if is_nil(get_field(changeset, :modifier_id)) do
      add_error(changeset, :modifier_id, "was not claimed")
    else
      changeset
    end
  end

  defp validate_source_is_not_target(changeset) do
    source_id = get_field(changeset, :image_id)
    target_id = get_field(changeset, :duplicate_of_image_id)

    if source_id == target_id do
      add_error(changeset, :image_id, "must be different from the target")
    else
      changeset
    end
  end
end
