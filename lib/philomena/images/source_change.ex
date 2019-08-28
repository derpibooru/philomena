defmodule Philomena.Images.SourceChange do
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

    timestamps(inserted_at: :created_at)
  end

  @doc false
  def changeset(source_change, attrs) do
    source_change
    |> cast(attrs, [])
    |> validate_required([])
  end
end
