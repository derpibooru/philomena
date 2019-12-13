defmodule Philomena.Bans.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Repo
  alias RelativeDate.Parser

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

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(user_ban, attrs) do
    user_ban
    |> cast(attrs, [])
    |> populate_until()
    |> populate_username()
  end

  def save_changeset(user_ban, attrs) do
    user_ban
    |> cast(attrs, [:reason, :note, :enabled, :override_ip_ban, :username, :until])
    |> populate_valid_until()
    |> populate_user_id()
    |> put_ban_id()
    |> validate_required([:reason, :enabled, :user_id, :valid_until])
  end

  defp populate_until(%{data: data} = changeset) do
    put_change(changeset, :until, to_string(data.valid_until))
  end

  defp populate_valid_until(changeset) do
    changeset
    |> get_field(:until)
    |> Parser.parse()
    |> case do
      {:ok, time} ->
        change(changeset, valid_until: time)

      {:error, _err} ->
        add_error(changeset, :until, "is not a valid absolute or relative date and time")
    end
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

  defp put_ban_id(%{data: %{generated_ban_id: nil}} = changeset) do
    ban_id = Base.encode16(:crypto.strong_rand_bytes(3))

    put_change(changeset, :generated_ban_id, "U#{ban_id}")
  end
  defp put_ban_id(changeset), do: changeset

  defp maybe_get_by(_field, nil), do: nil
  defp maybe_get_by(field, value), do: Repo.get_by(User, [{field, value}])
end
