defmodule PhilomenaWeb.ChannelControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  # The read-only actions (:index, :show) and the staff-facing write
  # actions (:new, :create, :edit, :update, :delete) are covered here.

  import Philomena.ChannelsFixtures

  alias Philomena.Channels
  alias Philomena.Channels.Channel
  alias Philomena.Repo

  # Channels are authorized against Channel, which every moderator (and admin)
  # can act on - no role_map grant needed. The write routes sit in the
  # require_authenticated_user scope, so anonymous users are bounced to login
  # before authorization runs.

  defp fetched_channel_fixture(attrs) do
    # A channel only appears in the index once the fetcher has stamped
    # last_fetched_at; update_fetch_state is the changeset the fetcher
    # uses (update_channel only casts type and short_name).
    {:ok, channel} =
      channel_fixture()
      |> Channels.update_fetch_state(Map.put(attrs, "last_fetched_at", DateTime.utc_now()))

    channel
  end

  defp valid_channel_params(extra \\ %{}) do
    Enum.into(extra, %{
      "type" => "PicartoChannel",
      "short_name" => "created_#{System.unique_integer([:positive])}"
    })
  end

  describe "GET /channels" do
    test "renders fetched channels for anonymous users", %{conn: conn} do
      channel = fetched_channel_fixture(%{"title" => "Test Pony Stream"})

      conn = get(conn, ~p"/channels")
      response = html_response(conn, 200)

      assert response =~ "Livestreams - Derpibooru"
      assert response =~ "Test Pony Stream"
      assert response =~ ~p"/channels/#{channel}"
    end

    test "does not list channels that have never been fetched", %{conn: conn} do
      {:ok, _unfetched} =
        Channels.update_fetch_state(channel_fixture(), %{"title" => "Test Unfetched Stream"})

      conn = get(conn, ~p"/channels")
      response = html_response(conn, 200)

      refute response =~ "Test Unfetched Stream"
    end

    test "hides NSFW channels without the chan_nsfw cookie", %{conn: conn} do
      _nsfw = fetched_channel_fixture(%{"title" => "Test NSFW Stream", "nsfw" => true})

      conn = get(conn, ~p"/channels")
      response = html_response(conn, 200)

      refute response =~ "Test NSFW Stream"
    end

    test "shows NSFW channels with the chan_nsfw cookie", %{conn: conn} do
      _nsfw = fetched_channel_fixture(%{"title" => "Test NSFW Stream", "nsfw" => true})

      conn =
        conn
        |> put_req_cookie("chan_nsfw", "true")
        |> get(~p"/channels")

      response = html_response(conn, 200)

      assert response =~ "Test NSFW Stream"
    end

    test "filters channels with the cq parameter", %{conn: conn} do
      _matching = fetched_channel_fixture(%{"title" => "Test Matching Stream"})
      _other = fetched_channel_fixture(%{"title" => "Unrelated Broadcast"})

      conn = get(conn, ~p"/channels?cq=test+match")
      response = html_response(conn, 200)

      assert response =~ "Test Matching Stream"
      refute response =~ "Unrelated Broadcast"
    end

    test "does not render management controls for anonymous viewers", %{conn: conn} do
      channel = fetched_channel_fixture(%{"title" => "Public Stream"})

      conn = get(conn, ~p"/channels")
      response = html_response(conn, 200)

      assert response =~ channel.title
      refute response =~ ~p"/channels/#{channel}/edit"
      refute response =~ "Are you really, really sure?"
      refute response =~ ~p"/channels/new"
    end

    test "renders management controls for a moderator", %{conn: conn} do
      channel = fetched_channel_fixture(%{"title" => "Moderator Stream"})
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/channels")
      response = html_response(conn, 200)

      assert response =~ ~p"/channels/#{channel}/edit"
      assert response =~ "Are you really, really sure?"
      assert response =~ ~p"/channels/new"
    end

    test "does not render management controls for a regular user", %{conn: conn} do
      channel = fetched_channel_fixture(%{"title" => "User Stream"})
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/channels")
      response = html_response(conn, 200)

      assert response =~ channel.title
      refute response =~ ~p"/channels/#{channel}/edit"
      refute response =~ "Are you really, really sure?"
      refute response =~ ~p"/channels/new"
    end
  end

  describe "GET /channels/:id" do
    test "redirects anonymous users to the external stream URL", %{conn: conn} do
      channel = channel_fixture()

      conn = get(conn, ~p"/channels/#{channel}")

      assert redirected_to(conn) == "https://picarto.tv/#{channel.short_name}"
    end

    test "redirects to / for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/channels/999999")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end
  end

  describe "GET /channels/new" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/channels/new")

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "redirects to / for a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/channels/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You can't access that page."
    end

    test "renders the form for a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/channels/new")
      response = html_response(conn, 200)

      assert response =~ "New Channel - Derpibooru"
      assert response =~ "Adding Channel"
    end

    test "renders the form for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/channels/new")

      assert html_response(conn, 200) =~ "Adding Channel"
    end

    test "renders the form for a moderator without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(without_fingerprint(conn), ~p"/channels/new")

      assert html_response(conn, 200) =~ "New Channel - Derpibooru"
    end
  end

  describe "POST /channels (create)" do
    test "redirects anonymous users to the login page", %{conn: conn} do
      conn = post(conn, ~p"/channels", %{"channel" => valid_channel_params()})

      assert redirected_to(conn) == ~p"/sessions/new"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      params = valid_channel_params(%{"short_name" => "nope_channel"})
      conn = post(conn, ~p"/channels", %{"channel" => params})

      assert redirected_to(conn) == "/"
      refute Repo.get_by(Channel, short_name: "nope_channel")
    end

    test "creates a channel as a moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      params = valid_channel_params(%{"short_name" => "mod_channel"})
      conn = post(conn, ~p"/channels", %{"channel" => params})

      assert redirected_to(conn) == ~p"/channels"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "created successfully"
      assert Repo.get_by(Channel, short_name: "mod_channel")
    end

    test "creates a channel as an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      params = valid_channel_params(%{"short_name" => "admin_channel"})
      conn = post(conn, ~p"/channels", %{"channel" => params})

      assert redirected_to(conn) == ~p"/channels"
      assert Repo.get_by(Channel, short_name: "admin_channel")
    end

    test "re-renders the form on a validation failure", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      # An unsupported channel type fails Channel.changeset's inclusion check.
      params = valid_channel_params(%{"short_name" => "bad_channel", "type" => "TwitchChannel"})
      conn = post(conn, ~p"/channels", %{"channel" => params})

      assert html_response(conn, 200) =~ "Adding Channel"
      refute Repo.get_by(Channel, short_name: "bad_channel")
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        post(without_fingerprint(conn), ~p"/channels", %{
          "channel" => valid_channel_params(%{"short_name" => "fingerprintless"})
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(Channel, short_name: "fingerprintless")
    end
  end

  describe "GET /channels/:id/edit" do
    test "rejects a regular user", %{conn: conn} do
      channel = channel_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/channels/#{channel}/edit")

      assert redirected_to(conn) == "/"
    end

    test "renders the edit form for a moderator", %{conn: conn} do
      channel = channel_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/channels/#{channel}/edit")

      assert html_response(conn, 200) =~ "Editing Channel"
    end

    test "renders the edit form for an admin", %{conn: conn} do
      channel = channel_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/channels/#{channel}/edit")

      assert html_response(conn, 200) =~ "Editing Channel"
    end

    test "redirects with a not-found flash on an unknown id for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = get(conn, ~p"/channels/999999/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking"
    end

    test "redirects with the not-found flash for a non-integer id", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = get(conn, ~p"/channels/not-a-number/edit")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking"
    end

    test "renders the edit form for a moderator without a fingerprint", %{conn: conn} do
      channel = channel_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = get(without_fingerprint(conn), ~p"/channels/#{channel}/edit")

      assert html_response(conn, 200) =~ "Editing Channel"
    end
  end

  describe "PATCH /channels/:id (update)" do
    test "rejects a regular user", %{conn: conn} do
      channel = channel_fixture(%{"short_name" => "keep_me"})
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = patch(conn, ~p"/channels/#{channel}", %{"channel" => %{"short_name" => "hacked"}})

      assert redirected_to(conn) == "/"
      assert Repo.get(Channel, channel.id).short_name == "keep_me"
    end

    test "updates the channel as a moderator", %{conn: conn} do
      channel = channel_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/channels/#{channel}", %{"channel" => %{"short_name" => "renamed_channel"}})

      assert redirected_to(conn) == ~p"/channels"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "updated successfully"
      assert Repo.get(Channel, channel.id).short_name == "renamed_channel"
    end

    # NOTE: update_channel casts only :type and :short_name (via
    # Channel.changeset); the fetcher-managed fields (title, nsfw, is_live,
    # viewers, thumbnail_url, last_fetched_at) go through update_fetch_state
    # and are silently ignored here.
    test "ignores fetcher-managed fields in the update", %{conn: conn} do
      channel = fetched_channel_fixture(%{"title" => "Original Title"})
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/channels/#{channel}", %{
          "channel" => %{"short_name" => channel.short_name, "title" => "New Title"}
        })

      assert redirected_to(conn) == ~p"/channels"
      assert Repo.get(Channel, channel.id).title == "Original Title"
    end

    test "re-renders the edit form on a validation failure", %{conn: conn} do
      channel = channel_fixture(%{"short_name" => "keep_me_valid"})
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(conn, ~p"/channels/#{channel}", %{"channel" => %{"type" => "TwitchChannel"}})

      assert html_response(conn, 200) =~ "Editing Channel"
      assert Repo.get(Channel, channel.id).type == "PicartoChannel"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      channel = channel_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn =
        patch(without_fingerprint(conn), ~p"/channels/#{channel}", %{
          "channel" => %{"short_name" => "renamed_channel"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(Channel, channel.id).short_name == channel.short_name
    end
  end

  describe "PUT /channels/:id (update)" do
    test "updates the channel as an admin", %{conn: conn} do
      channel = channel_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn =
        put(conn, ~p"/channels/#{channel}", %{"channel" => %{"short_name" => "put_renamed"}})

      assert redirected_to(conn) == ~p"/channels"
      assert Repo.get(Channel, channel.id).short_name == "put_renamed"
    end
  end

  describe "DELETE /channels/:id" do
    test "rejects a regular user", %{conn: conn} do
      channel = channel_fixture()
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = delete(conn, ~p"/channels/#{channel}")

      assert redirected_to(conn) == "/"
      assert Repo.get(Channel, channel.id)
    end

    test "deletes the channel as a moderator", %{conn: conn} do
      channel = channel_fixture()
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})

      conn = delete(conn, ~p"/channels/#{channel}")

      assert redirected_to(conn) == ~p"/channels"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "destroyed successfully"
      refute Repo.get(Channel, channel.id)
    end

    test "deletes the channel as an admin", %{conn: conn} do
      channel = channel_fixture()
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = delete(conn, ~p"/channels/#{channel}")

      assert redirected_to(conn) == ~p"/channels"
      refute Repo.get(Channel, channel.id)
    end

    test "redirects with a not-found flash on an unknown id for an admin", %{conn: conn} do
      %{conn: conn} = register_and_log_in_admin(%{conn: conn})

      conn = delete(conn, ~p"/channels/999999")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking"
    end
  end
end
