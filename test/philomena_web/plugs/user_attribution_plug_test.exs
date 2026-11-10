defmodule PhilomenaWeb.UserAttributionPlugTest do
  @moduledoc """
  Unit tests for `PhilomenaWeb.UserAttributionPlug`.

  The plug assigns the `%Philomena.Attribution.Actor{}` struct,
  built from the the user, connecting IP address, and fingerprint.
  These tests assert that the fingerprint source differs by path:
  the `_ses` cookie for normal requests, and `"a" <> crc32(user-agent)`
  for `/api/...` requests.
  """

  use PhilomenaWeb.ConnCase, async: true

  import Philomena.UsersFixtures
  import Philomena.BansFixtures

  alias PhilomenaWeb.UserAttributionPlug
  alias Philomena.Attribution.Actor

  # A fresh conn (not the ConnCase default, which presets a random `_ses`
  # cookie) with a deterministic remote_ip, `_ses` cookie, user-agent, and the
  # `current_user` assign the plug reads.
  defp build_attribution_conn(opts) do
    path_info = Keyword.get(opts, :path_info, ["images"])
    current_user = Keyword.get(opts, :current_user)

    build_conn()
    |> Map.put(:remote_ip, {10, 0, 0, 1})
    |> Map.put(:path_info, path_info)
    |> put_req_header("user-agent", "TestAgent/1.0")
    |> assign(:fingerprint, "test-session-fingerprint")
    |> assign(:current_user, current_user)
  end

  describe "call/2 for a normal (non-API) request" do
    test "assigns :actor consistent with the fingerprint" do
      {:ok, expected_ip} = EctoNetwork.INET.cast({10, 0, 0, 1})

      conn =
        build_attribution_conn(path_info: ["images"], current_user: nil)
        |> UserAttributionPlug.call([])

      assert %Actor{} = actor = conn.assigns.actor
      assert actor.ip == expected_ip
      assert actor.fingerprint == "test-session-fingerprint"
      assert actor.user == nil
    end

    test "carries the logged-in user through to the actor" do
      user = confirmed_user_fixture()

      conn =
        build_attribution_conn(path_info: ["images"], current_user: user)
        |> UserAttributionPlug.call([])

      assert conn.assigns.actor.user == user
      # Fingerprint still comes from the cookie on a non-API path.
      assert conn.assigns.actor.fingerprint == "test-session-fingerprint"
    end
  end

  describe "call/2 ban field" do
    test "sets the :current_ban assign" do
      ban = fingerprint_ban_fixture(%{"fingerprint" => "test-session-fingerprint"})

      conn =
        build_attribution_conn(path_info: ["images"], current_user: nil)
        |> UserAttributionPlug.call([])

      assert conn.assigns.actor.ban.generated_ban_id == ban.generated_ban_id
      assert conn.assigns.current_ban.generated_ban_id == ban.generated_ban_id
    end

    test "is nil when there is no ban" do
      conn =
        build_attribution_conn(path_info: ["api", "v1", "json", "images"], current_user: nil)
        |> UserAttributionPlug.call([])

      assert conn.assigns.actor.ban == nil
      assert conn.assigns.current_ban == nil
    end
  end
end
