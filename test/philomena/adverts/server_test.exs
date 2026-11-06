defmodule Philomena.Adverts.ServerTest do
  # async: false - the server is registered globally, so concurrent request
  # tests would cast their own impressions into it.
  use Philomena.DataCase, async: false

  import Philomena.AdvertsFixtures

  alias Philomena.Adverts
  alias Philomena.Adverts.Advert

  test "impressions and clicks are written once per flush" do
    advert = advert_fixture()
    server = start_supervised!(Adverts.Server)

    assert Adverts.record_impression(advert) == :ok
    assert Adverts.record_impression(advert) == :ok
    assert {:ok, _advert} = Adverts.record_click(advert.id)
    :sys.get_state(server)
    assert %{impressions: 0, clicks: 0} = Repo.get!(Advert, advert.id)

    send(server, :flush)
    :sys.get_state(server)
    assert %{impressions: 2, clicks: 1} = Repo.get!(Advert, advert.id)
  end
end
