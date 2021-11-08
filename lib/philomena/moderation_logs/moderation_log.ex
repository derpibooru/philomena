defmodule Philomena.ModerationLogs.ModerationLog do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  schema "moderation_logs" do
    belongs_to :user, User

    field :body, :string
    field :type, :string
    field :subject_path, :string

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  @doc false
  def changeset(moderation_log, attrs) do
    moderation_log
    |> cast(attrs, [:body, :type, :subject_path])
    |> validate_required([:body, :type, :subject_path])
  end
end
