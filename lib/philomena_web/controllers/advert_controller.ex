defmodule PhilomenaWeb.AdvertController do
  use PhilomenaWeb, :controller

  alias Philomena.Adverts

  action_fallback PhilomenaWeb.FallbackController

  def show(conn, %{"id" => id}) do
    with {:ok, advert} <- Adverts.record_click(id) do
      redirect(conn, external: advert.link)
    end
  end
end
