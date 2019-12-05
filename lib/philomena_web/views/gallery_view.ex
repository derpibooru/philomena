defmodule PhilomenaWeb.GalleryView do
  use PhilomenaWeb, :view

  alias Philomena.ImageScope

  def scope(conn), do: ImageScope.scope(conn)

  def show_subscription_link?(%{id: id}, %{id: id}), do: false
  def show_subscription_link?(_user1, _user2), do: true
end
