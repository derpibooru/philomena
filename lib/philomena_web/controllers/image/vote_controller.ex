defmodule PhilomenaWeb.Image.VoteController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Repo
  alias Ecto.Multi

  plug PhilomenaWeb.Plugs.FilterBannedUsers
  plug :load_and_authorize_resource, model: Image, id_name: "image_id", persisted: true

  def create(conn, _params) do
    conn
  end

  def delete(conn, _params) do
    conn
  end
end