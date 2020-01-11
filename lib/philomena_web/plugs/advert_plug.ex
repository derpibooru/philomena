defmodule PhilomenaWeb.AdvertPlug do
  alias Philomena.Adverts
  alias Plug.Conn

  def init([]), do: []

  def call(conn, _opts) do
    user = conn.assigns.current_user
    image = conn.assigns[:image]
    show_ads? = show_ads?(user)

    conn
    |> maybe_assign_ad(image, show_ads?)
  end

  defp maybe_assign_ad(conn, nil, true),
    do: Conn.assign(conn, :advert, Adverts.random_live())

  defp maybe_assign_ad(conn, image, true),
    do: Conn.assign(conn, :advert, Adverts.random_live_for(image))

  defp maybe_assign_ad(conn, _image, _false),
    do: conn

  defp show_ads?(%{hide_advertisements: false}),
    do: true

  defp show_ads?(_user),
    do: true
end
