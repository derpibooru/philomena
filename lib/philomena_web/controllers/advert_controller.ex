defmodule PhilomenaWeb.AdvertController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.AdvertUpdater
  alias Philomena.Adverts.Advert

  plug :load_resource, model: Advert

  def show(conn, _params) do
    advert = conn.assigns.advert

    AdvertUpdater.cast(:click, advert.id)

    redirect(conn, external: advert.link)
  end
end
