defmodule PhilomenaWeb.ChannelControllerTest do
  use PhilomenaWeb.ConnCase

  alias Philomena.Channels

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:channel) do
    {:ok, channel} = Channels.create_channel(@create_attrs)
    channel
  end

  describe "index" do
    test "lists all channels", %{conn: conn} do
      conn = get(conn, Routes.channel_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Channels"
    end
  end

  describe "new channel" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.channel_path(conn, :new))
      assert html_response(conn, 200) =~ "New Channel"
    end
  end

  describe "create channel" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.channel_path(conn, :create), channel: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.channel_path(conn, :show, id)

      conn = get(conn, Routes.channel_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Channel"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.channel_path(conn, :create), channel: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Channel"
    end
  end

  describe "edit channel" do
    setup [:create_channel]

    test "renders form for editing chosen channel", %{conn: conn, channel: channel} do
      conn = get(conn, Routes.channel_path(conn, :edit, channel))
      assert html_response(conn, 200) =~ "Edit Channel"
    end
  end

  describe "update channel" do
    setup [:create_channel]

    test "redirects when data is valid", %{conn: conn, channel: channel} do
      conn = put(conn, Routes.channel_path(conn, :update, channel), channel: @update_attrs)
      assert redirected_to(conn) == Routes.channel_path(conn, :show, channel)

      conn = get(conn, Routes.channel_path(conn, :show, channel))
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, channel: channel} do
      conn = put(conn, Routes.channel_path(conn, :update, channel), channel: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Channel"
    end
  end

  describe "delete channel" do
    setup [:create_channel]

    test "deletes chosen channel", %{conn: conn, channel: channel} do
      conn = delete(conn, Routes.channel_path(conn, :delete, channel))
      assert redirected_to(conn) == Routes.channel_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.channel_path(conn, :show, channel))
      end
    end
  end

  defp create_channel(_) do
    channel = fixture(:channel)
    {:ok, channel: channel}
  end
end
