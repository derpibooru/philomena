defmodule PhilomenaWeb.AdvertController do
  use PhilomenaWeb, :controller

  alias Philomena.Adverts.Advert
  alias Philomena.Adverts

  plug :load_resource, model: Advert

  def show(conn, _params) do
    advert = conn.assigns.advert

    Adverts.record_click(advert)

    redirect(conn, external: advert.link)
  end
end
