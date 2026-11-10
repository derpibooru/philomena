defmodule Philomena.ModNotes.ModNote do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Reports.Report
  alias Philomena.DnpEntries.DnpEntry

  # Foreign key columns naming the note's target. Exactly one is set on a live
  # note; all are NULL on an orphaned note whose target was deleted.
  @target_columns [:user_id, :report_id, :dnp_entry_id]

  @type t :: %__MODULE__{}

  schema "mod_notes" do
    belongs_to :moderator, User

    belongs_to :user, User
    belongs_to :report, Report
    belongs_to :dnp_entry, DnpEntry

    field :body, :string

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc """
  Preloads to apply to the target associations so downstream views have the
  nested data they expect. Report targets carry the preloads so the report's
  own target can be rendered.
  """
  def target_preloads do
    [
      :user,
      report: [:user] ++ Report.target_preloads(),
      dnp_entry: [:requesting_user, :tag]
    ]
  end

  @doc false
  def changeset(mod_note, attrs \\ %{}) do
    mod_note
    |> cast(attrs, [:body])
    |> validate_required([:body])
  end

  @doc false
  def creation_changeset(mod_note, attrs, target) do
    mod_note
    |> cast(attrs, [:body])
    |> change(target)
    |> validate_required([:body])
    |> validate_target()
  end

  # A note must reference exactly one target on creation.
  defp validate_target(changeset) do
    set = Enum.count(@target_columns, &(not is_nil(get_field(changeset, &1))))

    if set == 1 do
      changeset
    else
      add_error(changeset, :target, "must reference exactly one target")
    end
  end
end
