defmodule Philomena.Galleries.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Galleries.Gallery
  alias Philomena.Users.User

  @primary_key false

  schema "gallery_subscriptions" do
    belongs_to :gallery, Gallery, primary_key: true
    belongs_to :user, User, primary_key: true
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [])
    |> validate_required([])
  end
end
