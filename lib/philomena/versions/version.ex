defmodule Philomena.Versions.Version do
  use Ecto.Schema
  import Ecto.Changeset

  schema "versions" do
    field :event, :string
    field :whodunnit, :string
    field :object, :string

    # fixme: rails polymorphic relation
    field :item_id, :integer
    field :item_type, :string

    field :user, :any, virtual: true
    field :parent, :any, virtual: true
    field :body, :string, virtual: true
    field :edit_reason, :string, virtual: true
    field :difference, :any, virtual: true

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  @doc false
  def changeset(version, attrs, item_id) do
    version
    |> cast(attrs, [:body, :edit_reason])
    |> put_object(item_id)
  end

  defp put_object(changeset, item_id) do
    body = get_field(changeset, :body)
    edit_reason = get_field(changeset, :edit_reason)

    object =
      Jason.encode!(%{
        id: item_id,
        body: body,
        edit_reason: edit_reason
      })

    change(changeset, object: object)
  end
end
