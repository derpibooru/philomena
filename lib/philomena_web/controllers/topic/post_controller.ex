defmodule PhilomenaWeb.Topic.PostController do
  use PhilomenaWeb, :controller

  #alias Philomena.{Forums.Forum}
  #alias Philomena.Posts

  plug PhilomenaWeb.FilterBannedUsersPlug
  plug PhilomenaWeb.CanaryMapPlug, create: :show, edit: :show, update: :show
  plug :load_and_authorize_resource, model: Forum, id_field: "short_name", id_name: "forum_id", persisted: true
end