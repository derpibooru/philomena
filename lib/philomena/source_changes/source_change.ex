defmodule Philomena.SourceChanges.SourceChange do
  use Ecto.Schema
  import Ecto.Changeset

  schema "source_changes" do
    belongs_to :user, Philomena.Users.User
    belongs_to :image, Philomena.Images.Image

    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :user_agent, :string, default: ""
    field :referrer, :string, default: ""
    field :new_value, :string
    field :initial, :boolean, default: false

    field :source_url, :string, source: :new_value

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(source_change, attrs) do
    source_change
    |> cast(attrs, [])
    |> validate_required([])
  end

  @doc false
  def creation_changeset(source_change, attrs, attribution) do
    source_change
    |> cast(attrs, [:source_url])
    |> change(attribution)
  end
end
