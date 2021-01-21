defmodule Philomena.Bans.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Repo
  alias Philomena.Schema.Time
  alias Philomena.Schema.BanId

  schema "user_bans" do
    belongs_to :user, User
    belongs_to :banning_user, User

    field :reason, :string
    field :note, :string
    field :enabled, :boolean, default: true
    field :valid_until, :utc_datetime
    field :generated_ban_id, :string
    field :override_ip_ban, :boolean, default: false

    field :username, :string, virtual: true
    field :until, :string, virtual: true

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(user_ban, attrs) do
    user_ban
    |> cast(attrs, [])
    |> Time.propagate_time(:valid_until, :until)
    |> populate_username()
  end

  def save_changeset(user_ban, attrs) do
    user_ban
    |> cast(attrs, [:reason, :note, :enabled, :override_ip_ban, :username, :until])
    |> Time.assign_time(:until, :valid_until)
    |> populate_user_id()
    |> BanId.put_ban_id("U")
    |> validate_required([:reason, :enabled, :user_id, :valid_until])
    |> check_constraint(:valid_until, name: :user_ban_duration_must_be_valid)
  end

  defp populate_username(changeset) do
    case maybe_get_by(:id, get_field(changeset, :user_id)) do
      nil -> changeset
      user -> put_change(changeset, :username, user.name)
    end
  end

  defp populate_user_id(changeset) do
    case maybe_get_by(:name, get_field(changeset, :username)) do
      nil -> changeset
      %{id: id} -> put_change(changeset, :user_id, id)
    end
  end

  defp maybe_get_by(_field, nil), do: nil
  defp maybe_get_by(field, value), do: Repo.get_by(User, [{field, value}])
end
