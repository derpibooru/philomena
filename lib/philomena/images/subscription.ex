defmodule Philomena.Images.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Images.Image
  alias Philomena.Users.User

  @primary_key false

  schema "image_subscriptions" do
    belongs_to :image, Image, primary_key: true
    belongs_to :user, User, primary_key: true
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [])
    |> validate_required([])
  end
end
