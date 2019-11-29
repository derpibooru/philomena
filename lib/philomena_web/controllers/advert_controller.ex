defmodule PhilomenaWeb.AdvertController do
  use PhilomenaWeb, :controller

  alias Philomena.Adverts
  alias Philomena.Adverts.Advert

  plug :load_resource, model: Advert

  def show(conn, _params) do
    advert = conn.assigns.advert

    Adverts.click(advert)

    conn
    |> redirect(external: advert.link)
  end
end