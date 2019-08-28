defmodule Philomena.Vpns.Vpn do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  schema "vpns" do
    field :ip, EctoNetwork.INET
  end

  @doc false
  def changeset(vpn, attrs) do
    vpn
    |> cast(attrs, [])
    |> validate_required([])
  end
end
