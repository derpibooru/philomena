defmodule Philomena.Bans.Fingerprint do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias RelativeDate.Parser

  schema "fingerprint_bans" do
    belongs_to :banning_user, User

    field :reason, :string
    field :note, :string
    field :enabled, :boolean, default: true
    field :valid_until, :utc_datetime
    field :fingerprint, :string
    field :generated_ban_id, :string

    field :until, :string, virtual: true

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(fingerprint_ban, attrs) do
    fingerprint_ban
    |> cast(attrs, [])
    |> populate_until()
  end

  def save_changeset(fingerprint_ban, attrs) do
    fingerprint_ban
    |> cast(attrs, [:reason, :note, :enabled, :fingerprint, :until])
    |> populate_valid_until()
    |> put_ban_id()
    |> validate_required([:reason, :enabled, :fingerprint, :valid_until])
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

  defp put_ban_id(%{data: %{generated_ban_id: nil}} = changeset) do
    ban_id = Base.encode16(:crypto.strong_rand_bytes(3))

    put_change(changeset, :generated_ban_id, "F#{ban_id}")
  end
  defp put_ban_id(changeset), do: changeset
end
