defmodule Philomena.SiteNotices.SiteNotice do
  use Ecto.Schema
  import Ecto.Changeset

  schema "site_notices" do
    belongs_to :user, Philomena.Users.User

    field :title, :string
    field :text, :string
    field :link, :string
    field :link_text, :string
    field :live, :boolean, default: false
    field :start_date, :naive_datetime
    field :finish_date, :naive_datetime

    timestamps(inserted_at: :created_At)
  end

  @doc false
  def changeset(site_notice, attrs) do
    site_notice
    |> cast(attrs, [])
    |> validate_required([])
  end
end
