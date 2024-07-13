defmodule Philomena.SiteNotices.SiteNotice do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  schema "site_notices" do
    belongs_to :user, User

    field :title, :string
    field :text, :string
    field :link, :string, default: ""
    field :link_text, :string, default: ""
    field :live, :boolean, default: true
    field :start_date, PhilomenaQuery.Ecto.RelativeDate
    field :finish_date, PhilomenaQuery.Ecto.RelativeDate

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(site_notice, attrs) do
    site_notice
    |> cast(attrs, [:title, :text, :link, :link_text, :live, :start_date, :finish_date])
    |> validate_required([:title, :text, :live, :start_date, :finish_date])
  end
end
