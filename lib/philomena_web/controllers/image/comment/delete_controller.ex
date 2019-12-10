defmodule PhilomenaWeb.Image.Comment.DeleteController do
  use PhilomenaWeb, :controller

  alias Philomena.Comments.Comment
  alias Philomena.Comments

  plug PhilomenaWeb.CanaryMapPlug, create: :hide, delete: :hide
  plug :load_and_authorize_resource, model: Comment, id_name: "comment_id", persisted: true

  def delete(conn, _params) do
  end
end
