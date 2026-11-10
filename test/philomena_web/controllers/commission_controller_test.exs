defmodule PhilomenaWeb.CommissionControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Philomena.CommissionsFixtures
  import Philomena.UsersFixtures

  alias Philomena.Repo
  alias Philomena.UserIps.UserIp

  # The directory only lists commissions whose owner has IP activity in the
  # last two weeks. UserIp rows are only ever written by UserAttributionPlug
  # internals (the changeset casts nothing), so tests insert directly.
  defp recently_active_user_fixture(attrs) do
    user = confirmed_user_fixture(attrs)

    Repo.insert!(%UserIp{
      user_id: user.id,
      ip: %Postgrex.INET{address: {203, 0, 113, 1}, netmask: 32},
      uses: 1
    })

    user
  end

  defp listed_commission_fixture(user, attrs \\ %{}) do
    commission = commission_fixture(user, attrs)
    commission_item_fixture(commission)
    commission
  end

  describe "GET /commissions" do
    test "an empty commission parameter uses the default directory query", %{conn: conn} do
      user = recently_active_user_fixture(%{name: "Test Empty Query Artist"})
      listed_commission_fixture(user)

      conn = get(conn, ~p"/commissions?commission=")

      assert html_response(conn, 200) =~ "Test Empty Query Artist"
    end

    test "renders listed commissions for anonymous users", %{conn: conn} do
      user = recently_active_user_fixture(%{name: "Test Commission Artist"})

      _commission =
        listed_commission_fixture(user, %{information: "Test commission sheet info"})

      conn = get(conn, ~p"/commissions")
      response = html_response(conn, 200)

      assert response =~ "Commissions - Derpibooru"
      assert response =~ "Commissions Directory"
      assert response =~ "Test Commission Artist"
    end

    test "does not list commissions without items", %{conn: conn} do
      user = recently_active_user_fixture(%{name: "Test Itemless Artist"})
      _commission = commission_fixture(user)

      conn = get(conn, ~p"/commissions")
      response = html_response(conn, 200)

      refute response =~ "Test Itemless Artist"
    end

    test "does not list closed commissions", %{conn: conn} do
      user = recently_active_user_fixture(%{name: "Test Closed Artist"})
      _commission = listed_commission_fixture(user, %{open: false})

      conn = get(conn, ~p"/commissions")
      response = html_response(conn, 200)

      refute response =~ "Test Closed Artist"
    end

    test "does not list commissions from users with no recent activity", %{conn: conn} do
      # No UserIp row at all - treated the same as stale activity.
      user = confirmed_user_fixture(%{name: "Test Inactive Artist"})
      _commission = listed_commission_fixture(user)

      conn = get(conn, ~p"/commissions")
      response = html_response(conn, 200)

      refute response =~ "Test Inactive Artist"
    end

    test "filters by item type", %{conn: conn} do
      sketch_user = recently_active_user_fixture(%{name: "Test Sketch Artist"})
      sketch_commission = commission_fixture(sketch_user)
      commission_item_fixture(sketch_commission, %{item_type: "Sketch"})

      plush_user = recently_active_user_fixture(%{name: "Test Plushie Artist"})
      plush_commission = commission_fixture(plush_user)
      commission_item_fixture(plush_commission, %{item_type: "Plushie"})

      conn = get(conn, ~p"/commissions?#{[commission: [item_type: "Plushie"]]}")
      response = html_response(conn, 200)

      assert response =~ "Test Plushie Artist"
      refute response =~ "Test Sketch Artist"
    end

    test "renders an empty result set on invalid search parameters", %{conn: conn} do
      # NOTE: an invalid search now renders an empty page (200) with an
      # error changeset rather than crashing the pagination partial on a
      # bare list.
      conn = get(conn, ~p"/commissions?#{[commission: [price_min: "not-a-price"]]}")
      response = html_response(conn, 200)

      assert response =~ "Commissions Directory"
    end
  end
end
